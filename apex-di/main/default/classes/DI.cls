/**
 * Copyright 2020 Jeff Jin
 * https://github.com/apexfarm/ApexDI
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

public with sharing class DI {
    private static final ResultCache RESULT_CACHE_NONE = new ResultCache(
        CallSiteResultCacheLocation.None, new ServiceCacheKey(null)
    );

    private static final RuntimeServiceProviderEngine RUNTIME_SERVICE_PROVIDER_ENGINE = new RuntimeServiceProviderEngine();
    private static final CallSiteRuntimeResolver CALL_SITE_RUNTIME_RESOLVER;
    @TestVisible
    // Singleton Module
    private static final RootModule ROOT_MODULE = new RootModule();
    private static final GlobalModuleCollectionImpl GLOBAL_MODULES = new GlobalModuleCollectionImpl();

    static {
        GLOBAL_MODULES.services.addScoped(RootModule.class.getName(), ROOT_MODULE);
        CALL_SITE_RUNTIME_RESOLVER = new CallSiteRuntimeResolver(ROOT_MODULE.provider.root);
    }

    public static GlobalModuleCollection modules() {
        return GLOBAL_MODULES;
    }

    public static ServiceCollection services() {
        return new ServiceCollectionImpl();
    }

    // ==============
    // #region Module
    private class ModuleCollectionImpl implements ModuleCollection {
        private List<String> moduleNames = new List<String>();

        public ModuleCollection add(String moduleName) {
            moduleNames.add(moduleName);
            return this;
        }
    }

    public class GlobalModuleCollectionImpl implements GlobalModuleCollection {
        private ServiceCollectionImpl services { get; set; }
        private ServiceProviderImpl provider { get; set; }
        private Map<String, String> moduleReplacements;

        private GlobalModuleCollectionImpl() {
            this.services = new ServiceCollectionImpl();
            this.provider = new ServiceProviderImpl(this.services.getDescriptors());
            this.moduleReplacements = new Map<String, String>();
        }

        public void replace(Type moduleType, Type newModuleType) {
            this.replace(moduleType.getName(), newModuleType.getName());
        }

        public void replace(String moduleTypeName, String newModuleTypeName) {
            this.moduleReplacements.put(moduleTypeName, newModuleTypeName);
            this.addModuleWithScopedFactory(newModuleTypeName);
        }

        public Module get(Type moduleType) {
            return this.get(moduleType.getName());
        }

        public Module get(String moduleName) {
            if (this.moduleReplacements.containsKey(moduleName)) {
                moduleName = this.moduleReplacements.get(moduleName);
            }

            Module module = (Module) this.provider.getService(moduleName);
            if (module == null) {
                this.provider.callSiteFactory.callSiteCache.remove(moduleName);
                this.provider.realizedServices.remove(moduleName);
                this.addModuleWithScopedFactory(moduleName);
            }
            return (Module) this.provider.getService(moduleName);
        }

        private void addModuleWithScopedFactory(string moduleName) {
            this.services.addScopedFactory(moduleName, 'DI.ModuleFactory');
        }
    }

    public class ModuleFactory implements DI.ServiceFactory {
        public Object newInstance(Type moduleType, ServiceProvider provider) {
            if (moduleType == null || !Module.class.isAssignableFrom(moduleType)) {
                throw new DITypeException('Module [' + moduleType + '] doesn\'t extend [DI.Module].');
            }

            Module module = (Module) moduleType.newInstance();
            module.services = new ServiceCollectionImpl();

            ModuleCollectionImpl modules = new ModuleCollectionImpl();
            module.import(modules);
            for (String moduleName : modules.moduleNames) {
                Module importedModule = GLOBAL_MODULES.get(moduleName);
                module.addModule(importedModule);
            }

            module.configure(module.services);
            module.addProvider();
            return module;
        }
    }

    private class RootModule extends Module {
        private RootModule() {
            this.services = new ServiceCollectionImpl();
            this.provider = new ServiceProviderImpl(this.services.getDescriptors());
        }

        private ServiceDescriptor add(ServiceDescriptor descriptor) {
            this.services.serviceDescriptors.put(descriptor.serviceName, descriptor);
            return descriptor;
        }

        protected override void configure(ServiceCollection services) {
        }
    }

    public abstract class Module implements ServiceProvider {
        @TestVisible
        private ServiceCollectionImpl services { get; set; }
        private ServiceProviderImpl provider { get; set; }

        public Object getService(Type serviceType) {
            return this.provider.getService(serviceType);
        }

        public Object getService(String serviceName) {
            return this.provider.getService(serviceName);
        }

        private void addModule(Module module) {
            this.services.addServices(module.services);
        }

        private void addProvider() {
            this.provider = new ServiceProviderImpl(this.services.getDescriptors());
        }

        protected virtual void import(ModuleCollection modules) {
        }

        protected abstract void configure(ServiceCollection services);
    }

    // #endregion
    // ==============

    // =========================
    // #region Service Providers

    private class ServiceProviderImpl implements ServiceProvider {
        private ServiceProviderEngine engine { get; set; }
        protected Map<String, ServiceRealizationFunc> realizedServices { get; private set; }
        private ServiceProviderEngineScope root { get; set; }
        private CallSiteFactory callSiteFactory { get; set; }
        private CallSiteRuntimeResolver callSiteResolver { get; set; }

        private ServiceProviderImpl(Map<String, ServiceDescriptor> serviceDescriptors) {
            this.root = new ServiceProviderEngineScope(this, true);
            this.realizedServices = new Map<String, ServiceRealizationFunc>();
            this.engine = RUNTIME_SERVICE_PROVIDER_ENGINE;

            this.callSiteFactory = new CallSiteFactory(serviceDescriptors);
            this.callSiteFactory.add(ServiceProvider.class.getName(), new ServiceProviderCallSite());
            this.callSiteResolver = CALL_SITE_RUNTIME_RESOLVER;
        }

        public Object getService(Type serviceType) {
            if (serviceType == null) {
                throw new DIIllegalArgumentException('getService(Type serviceType): serviceType cannot be null.');
            }

            return getService(serviceType.getName(), this.root);
        }

        public Object getService(String serviceName) {
            if (String.isBlank(serviceName)) {
                throw new DIIllegalArgumentException('getService(String serviceName): serviceName cannot be blank.');
            }

            return this.getService(serviceName.replace(' ', ''), this.root);
        }

        private Object getService(String serviceName, ServiceProviderEngineScope scope) {
            ServiceRealizationFunc realizedService;
            if (this.realizedServices.containsKey(serviceName)) {
                realizedService = this.realizedServices.get(serviceName);
            } else {
                realizedService = createServiceAccessor(serviceName);
                this.realizedServices.put(serviceName, realizedService);
            }
            return realizedService.invoke(scope);
        }

        private ServiceRealizationFunc createServiceAccessor(String serviceName) {
            ServiceCallSite callSite = this.callSiteFactory.getCallSite(serviceName);
            if (callSite != null) {
                return this.engine.realizeService(callSite);
            }

            return new NullServiceRealizationFunc();
        }

        private ServiceScope createScope() {
            return new ServiceProviderEngineScope(this, false);
        }
    }

    private class ServiceProviderEngineScope implements ServiceScope, ServiceProvider, ServiceScopeFactory {
        private Map<ServiceCacheKey, Object> resolvedServices { get; set; }
        private ServiceProviderImpl rootProvider { get; set; }
        private Boolean isRootScope { get; set; }

        private ServiceProviderEngineScope(ServiceProviderImpl provider, Boolean isRootScope) {
            this.resolvedServices = new Map<ServiceCacheKey, Object>();
            this.rootProvider = provider;
            this.isRootScope = isRootScope;
        }

        public ServiceProvider getServiceProvider() {
            return this;
        }

        public Object getService(Type serviceType) {
            if (serviceType == null) {
                throw new DIIllegalArgumentException('getService(Type serviceType): serviceType cannot be null.');
            }
            return this.rootProvider.getService(serviceType.getName(), this);
        }

        public Object getService(String serviceName) {
            if (String.isBlank(serviceName)) {
                throw new DIIllegalArgumentException('getService(String serviceName): serviceName cannot be blank.');
            }

            return this.rootProvider.getService(serviceName.replace(' ', ''), this);
        }

        public ServiceScope createScope() {
            return this.rootProvider.createScope();
        }
    }

    private abstract class ServiceProviderEngine {
        protected abstract ServiceRealizationFunc realizeService(ServiceCallSite callSite);
    }

    // Reference RUNTIME_SERVICE_PROVIDER_ENGINE as the singleton instance;
    private class RuntimeServiceProviderEngine extends ServiceProviderEngine {
        protected override ServiceRealizationFunc realizeService(ServiceCallSite callSite) {
            return new RuntimeServiceRealizationFunc(callSite);
        }
    }

    private class RuntimeServiceRealizationFunc implements ServiceRealizationFunc {
        private ServiceCallSite callSite { get; set; }

        private RuntimeServiceRealizationFunc(ServiceCallSite callSite) {
            this.callSite = callSite;
        }

        public Object invoke(ServiceProviderEngineScope scope) {
            return CALL_SITE_RUNTIME_RESOLVER.resolve(callSite, scope);
        }
    }

    private class NullServiceRealizationFunc implements ServiceRealizationFunc {
        public Object invoke(ServiceProviderEngineScope scope) {
            return null;
        }
    }

    // #endregion
    // =========================

    // ==================
    // #region Call Sites

    // Reference CALL_SITE_RUNTIME_RESOLVER as the singleton instance;
    private class CallSiteRuntimeResolver extends CallSiteVisitor {
        private ServiceProviderEngineScope rootScope { get; set; }

        private CallSiteRuntimeResolver(ServiceProviderEngineScope rootScope) {
            this.rootScope = rootScope;
        }

        private Object resolve(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            return visitCallSite(callSite, scope);
        }

        protected override Object visitRootCache(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            Map<ServiceCacheKey, Object> resolvedServices = this.rootScope.resolvedServices;
            if (!resolvedServices.containsKey(callSite.cache.key)) {
                resolvedServices.put(callSite.cache.key, visitCallSiteMain(callSite, this.rootScope));
            }
            return resolvedServices.get(callSite.cache.key);
        }

        protected override Object visitScopeCache(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            Map<ServiceCacheKey, Object> resolvedServices = scope.resolvedServices;
            if (!resolvedServices.containsKey(callSite.cache.key)) {
                resolvedServices.put(callSite.cache.key, visitCallSiteMain(callSite, scope));
            }
            return resolvedServices.get(callSite.cache.key);
        }
    }

    private abstract class CallSiteVisitor {
        protected virtual Object VisitCallSite(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            switch on callSite.cache.location {
                when Root {
                    return visitRootCache(callSite, scope);
                }
                when Scope {
                    return visitScopeCache(callSite, scope);
                }
                when Dispose {
                    return visitDisposeCache(callSite, scope);
                }
                when None {
                    return visitNoCache(callSite, scope);
                }
                when else {
                    throw new NoSuchElementException();
                }
            }
        }

        protected virtual Object visitCallSiteMain(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            return callSite.createInstance(scope);
        }

        protected virtual Object visitNoCache(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            return visitCallSiteMain(callSite, scope);
        }

        protected virtual Object visitDisposeCache(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            return visitCallSiteMain(callSite, scope);
        }

        protected virtual Object visitRootCache(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            return visitCallSiteMain(callSite, scope);
        }

        protected virtual Object visitScopeCache(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            return visitCallSiteMain(callSite, scope);
        }
    }

    private class CallSiteFactory {
        private Map<String, ServiceDescriptor> serviceDescriptors { get; set; }
        private Map<String, ServiceCallSite> callSiteCache { get; set; }

        private CallSiteFactory(Map<String, ServiceDescriptor> serviceDescriptors) {
            this.serviceDescriptors = serviceDescriptors;
            callSiteCache = new Map<String, ServiceCallSite>();
        }

        private void add(String serviceName, ServiceCallSite callSite) {
            this.callSiteCache.put(serviceName, callSite);
        }

        private ServiceCallSite getCallSite(String serviceName) {
            if (!callSiteCache.containsKey(serviceName)) {
                callSiteCache.put(serviceName, createCallSite(serviceName));
            }
            return callSiteCache.get(serviceName);
        }

        private ServiceCallSite createCallSite(String fullServiceName) {
            String serviceName = fullServiceName;
            if (serviceName.endsWith('>')) {
                String[] names = serviceName.split('<');
                serviceName = names[0];
            }
            return tryCreateExact(
                this.serviceDescriptors.get(serviceName),
                fullServiceName
            );
        }

        private ServiceCallSite tryCreateExact(
            ServiceDescriptor descriptor,
            String fullServiceName
        ) {
            if (descriptor != null) {
                ResultCache cache = new ResultCache(descriptor.lifetime, fullServiceName);
                return descriptor.createCallSite(cache);
            }

            return null;
        }
    }

    private class ResultCache {
        private CallSiteResultCacheLocation location { get; set; }
        private ServiceCacheKey key { get; set; }

        private ResultCache(CallSiteResultCacheLocation lifetime, ServiceCacheKey cacheKey) {
            Location = lifetime;
            Key = cacheKey;
        }

        private ResultCache(ServiceLifetime lifetime, String serviceName) {
            switch on lifetime {
                when SingletonLifetime {
                    this.location = CallSiteResultCacheLocation.Root;
                }
                when ScopedLifeTime {
                    this.location = CallSiteResultCacheLocation.Scope;
                }
                when TransientLifetime {
                    this.location = CallSiteResultCacheLocation.Dispose;
                }
                when else {
                    this.location = CallSiteResultCacheLocation.None;
                }
            }

            this.key = new ServiceCacheKey(serviceName);
        }
    }

    private class ServiceCacheKey {
        private String serviceName { get; set; }

        private ServiceCacheKey(String serviceName) {
            this.serviceName = serviceName;
        }

        public Boolean equals(Object obj) {
            if (this === obj) {
                return true;
            }

            ServiceCacheKey that = (ServiceCacheKey) obj;
            return this.serviceName == that.serviceName;
        }

        public Integer hashCode() {
            Integer hashCode = this.serviceName == null ? 23 : this.serviceName.hashCode();
            return hashCode;
        }
    }

    // #endregion
    // ==================

    // ===========================
    // #region Service Descriptors

    private abstract class ServiceDescriptor {
        private String serviceName { get; private set; }
        private ServiceLifetime lifetime { get; private set; }

        public abstract ServiceCallSite createCallSite(ResultCache cache);
    }

    private class ConstructorServiceDescriptor extends ServiceDescriptor {
        private String implementationTypeName { get; private set; }

        private ConstructorServiceDescriptor(
            String serviceName,
            String implementationTypeName,
            ServiceLifetime lifetime
        ) {
            this.serviceName = serviceName;
            this.implementationTypeName = implementationTypeName;
            this.lifetime = lifetime;
        }

        public override ServiceCallSite createCallSite(ResultCache cache) {
            return new ConstructorCallSite(cache, this.serviceName, this.implementationTypeName);
        }
    }

    private class FactoryServiceDescriptor extends ServiceDescriptor {
        private String factoryTypeName { get; private set; }

        private FactoryServiceDescriptor(String serviceName, String factoryName, ServiceLifetime lifetime) {
            String factoryTypeName = factoryName;
            if (factoryName.endsWith('>')) {
                String[] names = factoryName.split('<');
                factoryTypeName = names[0];
            }

            this.serviceName = serviceName;
            this.factoryTypeName = factoryTypeName;
            this.lifetime = lifetime;
        }

        public override ServiceCallSite createCallSite(ResultCache cache) {
            List<Type> parameterTypes = null;
            String fullServiceName = cache.key.serviceName;
            if (fullServiceName.endsWith('>')) {
                parameterTypes = new List<Type>();
                List<String> splits = fullServiceName.replace('>', '').split('<');
                for (String genericName : splits[1].split(',')) {
                    parameterTypes.add(Type.forName(genericName.trim()));
                }
            }

            return new FactoryCallSite(
                cache,
                this.serviceName,
                this.factoryTypeName,
                parameterTypes
            );
        }
    }

    private class ConstantServiceDescriptor extends ServiceDescriptor {
        private Object implementationInstance { get; private set; }

        private ConstantServiceDescriptor(String serviceName, Object instance, ServiceLifetime lifetime) {
            this.serviceName = serviceName;
            this.implementationInstance = instance;
            this.lifetime = lifetime;
        }

        public override ServiceCallSite createCallSite(ResultCache cache) {
            return new ConstantCallSite(this.serviceName, this.implementationInstance);
        }
    }

    // #endregion
    // ==========================

    // ==========================
    // #region Service Call Sites
    private abstract class ServiceCallSite {
        protected String serviceName { get; set; }
        protected Type implementationType { get; set; }
        protected CallSiteKind kind { get; set; }
        protected ResultCache cache { get; set; }

        private ServiceCallSite(ResultCache cache) {
            this.cache = cache;
        }

        public abstract Object createInstance(ServiceProviderEngineScope scope);
    }

    private class ConstructorCallSite extends ServiceCallSite {
        private ConstructorCallSite(ResultCache cache, String serviceName, String implementationTypeName) {
            super(cache);
            this.serviceName = serviceName;
            this.implementationType = Type.forName(implementationTypeName);

            if (this.implementationType == null) {
                throw new DITypeException(
                    'Implementation [' + implementationTypeName + '] doesn\'t exist for [' + serviceName + '].'
                );
            }

            this.kind = CallSiteKind.Constructor;
        }

        public override Object createInstance(ServiceProviderEngineScope scope) {
            return this.implementationType.newInstance();
        }
    }

    private class FactoryCallSite extends ServiceCallSite {
        private IServiceFactory factory { get; set; }
        private List<Type> parameterTypes { get; set; }

        private FactoryCallSite(
            ResultCache cache,
            String serviceName,
            String factoryTypeName,
            List<Type> parameterTypes
        ) {
            super(cache);
            Type factoryType = Type.forName(factoryTypeName);

            if (factoryType == null) {
                throw new DITypeException(
                    'Factory [' + factoryTypeName + '] doesn\'t exist for [' + serviceName + '].'
                );
            }

            if (
                !ServiceFactory.class.isAssignableFrom(factoryType) &&
                !GenericServiceFactory.class.isAssignableFrom(factoryType)
            ) {
                throw new DITypeException(
                    'Factory [' +
                        factoryType +
                        '] doesn\'t implement [DI.ServiceFactory] or [DI.GenericServiceFactory].'
                );
            }

            this.kind = CallSiteKind.Factory;
            this.serviceName = serviceName;
            this.parameterTypes = parameterTypes;
            this.factory = (IServiceFactory) factoryType.newInstance();
        }

        public override Object createInstance(ServiceProviderEngineScope scope) {
            if (this.factory instanceof ServiceFactory) {
                return ((ServiceFactory) this.factory).newInstance(Type.forName(this.serviceName), scope);
            } else if (this.factory instanceof GenericServiceFactory) {
                return ((GenericServiceFactory) this.factory)
                    .newInstance(Type.forName(this.serviceName), scope, this.parameterTypes);
            }
            throw new NoSuchElementException();
        }
    }

    private class ConstantCallSite extends ServiceCallSite {
        private Object defaultValue { get; set; }

        private ConstantCallSite(String serviceName, Object defaultValue) {
            super(RESULT_CACHE_NONE);
            this.serviceName = serviceName;
            this.defaultValue = defaultValue;
            this.kind = CallSiteKind.Constant;
        }

        public override Object createInstance(ServiceProviderEngineScope scope) {
            return this.defaultValue;
        }
    }

    private class ServiceProviderCallSite extends ServiceCallSite {
        private ServiceProviderCallSite() {
            super(RESULT_CACHE_NONE);
            this.serviceName = ServiceProvider.class.getName();
            this.kind = CallSiteKind.ServiceProvider;
        }

        public override Object createInstance(ServiceProviderEngineScope scope) {
            return scope;
        }
    }
    // #endregion
    // ==========================

    // ==========================
    // #region Service Collection

    @TestVisible
    private virtual class ServiceCollectionImpl implements IServiceCollection {
        private final Map<String, ServiceDescriptor> serviceDescriptors;

        {
            serviceDescriptors = new Map<String, ServiceDescriptor>();
        }

        public Map<String, ServiceDescriptor> getDescriptors() {
            return this.serviceDescriptors;
        }

        public ServiceProvider buildServiceProvider() {
            return new ServiceProviderImpl(serviceDescriptors);
        }

        public ServiceCollection addTransient(String serviceName) {
            ServiceDescriptor descriptor = new ConstructorServiceDescriptor(
                serviceName,
                serviceName,
                ServiceLifetime.TransientLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            return this;
        }

        public ServiceCollection addTransient(String serviceName, String implementationTypeName) {
            ServiceDescriptor descriptor = new ConstructorServiceDescriptor(
                serviceName,
                implementationTypeName,
                ServiceLifetime.TransientLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            return this;
        }

        public ServiceCollection addTransientFactory(String serviceName, String factoryTypeName) {
            ServiceDescriptor descriptor = new FactoryServiceDescriptor(
                serviceName,
                factoryTypeName,
                ServiceLifetime.TransientLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            return this;
        }

        public ServiceCollection addTransient(String serviceName, Object instance) {
            ServiceDescriptor descriptor = new ConstantServiceDescriptor(
                serviceName,
                instance,
                ServiceLifetime.TransientLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            return this;
        }

        public ServiceCollection addScoped(String serviceName) {
            ServiceDescriptor descriptor = new ConstructorServiceDescriptor(
                serviceName,
                serviceName,
                ServiceLifetime.ScopedLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            return this;
        }

        public ServiceCollection addScoped(String serviceName, String implementationTypeName) {
            ServiceDescriptor descriptor = new ConstructorServiceDescriptor(
                serviceName,
                implementationTypeName,
                ServiceLifetime.ScopedLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            return this;
        }

        public ServiceCollection addScopedFactory(String serviceName, String factoryTypeName) {
            ServiceDescriptor descriptor = new FactoryServiceDescriptor(
                serviceName,
                factoryTypeName,
                ServiceLifetime.ScopedLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            return this;
        }

        public ServiceCollection addScoped(String serviceName, Object instance) {
            ServiceDescriptor descriptor = new ConstantServiceDescriptor(
                serviceName,
                instance,
                ServiceLifetime.ScopedLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            return this;
        }

        public ServiceCollection addSingleton(String serviceName) {
            ServiceDescriptor descriptor = new ConstructorServiceDescriptor(
                serviceName,
                serviceName,
                ServiceLifetime.SingletonLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            ROOT_MODULE.add(descriptor);
            return this;
        }

        public ServiceCollection addSingleton(String serviceName, String implementationTypeName) {
            ServiceDescriptor descriptor = new ConstructorServiceDescriptor(
                serviceName,
                implementationTypeName,
                ServiceLifetime.SingletonLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            ROOT_MODULE.add(descriptor);
            return this;
        }

        public ServiceCollection addSingletonFactory(String serviceName, String factoryTypeName) {
            ServiceDescriptor descriptor = new FactoryServiceDescriptor(
                serviceName,
                factoryTypeName,
                ServiceLifetime.SingletonLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            ROOT_MODULE.add(descriptor);
            return this;
        }

        public ServiceCollection addSingleton(String serviceName, Object instance) {
            ServiceDescriptor descriptor = new ConstantServiceDescriptor(
                serviceName,
                instance,
                ServiceLifetime.SingletonLifeTime
            );
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            ROOT_MODULE.add(descriptor);
            return this;
        }

        public ServiceCollection addServices(IServiceCollection services) {
            this.serviceDescriptors.putAll(services.getDescriptors());
            return this;
        }
    }
    // #endregion
    // ==========================

    // ==================
    // #region Exceptions
    public virtual class DIException extends Exception {
    }

    public virtual class DIIllegalArgumentException extends DIException {
    }

    public class DITypeException extends DIIllegalArgumentException {
    }

    // #endregion
    // ==================

    // =============
    // #region Enums
    private enum ServiceLifetime {
        TransientLifeTime,
        SingletonLifeTime,
        ScopedLifeTime
    }

    private enum CallSiteKind {
        Factory,
        Constant,
        Constructor,
        ServiceProvider,
        Transient,
        Singleton,
        Scoped
    }

    private enum CallSiteResultCacheLocation {
        Root,
        Scope,
        Dispose,
        None
    }
    // #endregion
    // =============

    // ==================
    // #region Interfaces
    private interface IServiceFactory {
    }

    public interface ServiceFactory extends IServiceFactory {
        Object newInstance(Type serviceType, ServiceProvider provider);
    }

    public interface GenericServiceFactory extends IServiceFactory {
        Object newInstance(Type serviceType, ServiceProvider provider, List<Type> parameterTypes);
    }

    public interface ServiceCollection {
        ServiceProvider buildServiceProvider();

        ServiceCollection addTransient(String serviceTypeName);
        ServiceCollection addTransient(String serviceTypeName, Object instance);
        ServiceCollection addTransient(String serviceTypeName, String implementationTypeName);
        ServiceCollection addTransientFactory(String serviceTypeName, String factoryTypeName);

        ServiceCollection addSingleton(String serviceTypeName);
        ServiceCollection addSingleton(String serviceTypeName, Object instance);
        ServiceCollection addSingleton(String serviceTypeName, String implementationTypeName);
        ServiceCollection addSingletonFactory(String serviceTypeName, String factoryTypeName);

        ServiceCollection addScoped(String serviceName);
        ServiceCollection addScoped(String serviceTypeName, Object instance);
        ServiceCollection addScoped(String serviceName, String implementationTypeName);
        ServiceCollection addScopedFactory(String serviceName, String factoryTypeName);
    }

    private interface IServiceCollection extends ServiceCollection {
        Map<String, ServiceDescriptor> getDescriptors();
        ServiceCollection addServices(IServiceCollection services);
    }

    public interface ServiceProvider {
        Object getService(Type serviceType);
        Object getService(String serviceName);
    }

    public interface ServiceScope {
        ServiceProvider getServiceProvider();
    }

    public interface ServiceScopeFactory {
        ServiceScope createScope();
    }

    private interface ServiceRealizationFunc {
        Object invoke(ServiceProviderEngineScope scope);
    }

    public interface ModuleCollection {
        ModuleCollection add(String moduleName);
    }

    public interface GlobalModuleCollection {
        Module get(String moduleName);
        Module get(Type moduleType);
        void replace(String moduleName, String newModuleName);
        void replace(Type moduleType, Type newModuleType);
    }

    // #endregion
    // ==================
}

// @startuml
// ServiceProvider -> CallSiteFactory: getCallSite()
// ServiceProvider <- CallSiteFactory: callSite
// ServiceProvider -> ServiceProviderEngine: realizeService(callSite)
// ServiceProvider <- ServiceProviderEngine: realizedService
// ServiceProvider -> ServiceRealizationFunc: invoke(scope)
// ServiceRealizationFunc-> CallSiteVisitor: resolve(callSite, scope)
// CallSiteVisitor-> CallSiteVisitor: visitCallSite(callSite, scope)
// @enduml

// ┌───────────────┐          ┌───────────────┐          ┌─────────────────────┐          ┌──────────────────────┐          ┌───────────────┐
// │ServiceProvider│          │CallSiteFactory│          │ServiceProviderEngine│          │ServiceRealizationFunc│          │CallSiteVisitor│
// └───────┬───────┘          └───────┬───────┘          └──────────┬──────────┘          └──────────┬───────────┘          └───────┬───────┘
//         │      getCallSite()       │                             │                                │                              │
//         │─────────────────────────>│                             │                                │                              │
//         │                          │                             │                                │                              │
//         │        callSite          │                             │                                │                              │
//         │<─────────────────────────│                             │                                │                              │
//         │                          │                             │                                │                              │
//         │               realizeService(callSite)                 │                                │                              │
//         │───────────────────────────────────────────────────────>│                                │                              │
//         │                          │                             │                                │                              │
//         │                    realizedService                     │                                │                              │
//         │<───────────────────────────────────────────────────────│                                │                              │
//         │                          │                             │                                │                              │
//         │                          │          invoke(scope)      │                                │                              │
//         │────────────────────────────────────────────────────────────────────────────────────────>│                              │
//         │                          │                             │                                │                              │
//         │                          │                             │                                │   resolve(callSite, scope)   │
//         │                          │                             │                                │─────────────────────────────>│
//         │                          │                             │                                │                              │
//         │                          │                             │                                │                              ────┐
//         │                          │                             │                                │                                  │ visitCallSite(callSite, scope)
//         │                          │                             │                                │                              <───┘
// ┌───────┴───────┐          ┌───────┴───────┐          ┌──────────┴──────────┐          ┌──────────┴───────────┐          ┌───────┴───────┐
// │ServiceProvider│          │CallSiteFactory│          │ServiceProviderEngine│          │ServiceRealizationFunc│          │CallSiteVisitor│
// └───────────────┘          └───────────────┘          └─────────────────────┘          └──────────────────────┘          └───────────────┘

