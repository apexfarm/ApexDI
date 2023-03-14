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

// TODO: implement CallSiteChain to check circular dependency

public with sharing class DI {
    private static final String DEFAULT_MODULE = 'Default';
    private static final ResultCache RESULT_CACHE_NONE = new ResultCache(
        CallSiteResultCacheLocation.None,
        new ServiceCacheKey(null, 0)
    );
    private static final CallSiteRuntimeResolver CALL_SITE_RUNTIME_RESOLVER; // singleton
    private static final RuntimeServiceProviderEngine RUNTIME_SERVICE_PROVIDER_ENGINE = new RuntimeServiceProviderEngine(); // singleton

    private static final ModuleCollectionImpl GLOBAL_MODULES = new ModuleCollectionImpl();
    private static final GlobalModule GLOBAL_MODULE;

    static {
        GLOBAL_MODULE = new GlobalModule();
        GLOBAL_MODULES.services.addScoped(GlobalModule.class.getName(), GLOBAL_MODULE);
        CALL_SITE_RUNTIME_RESOLVER = new CallSiteRuntimeResolver(GLOBAL_MODULE.provider.root);
    }

    public static void addModule(String moduleTypeName, String newModuleTypeName) {
        addModule(Type.forName(moduleTypeName), Type.forName(newModuleTypeName));
    }

    public static void addModule(Type moduleType, Type newModuleType) {
        if (moduleType == null || !Module.class.isAssignableFrom(moduleType)) {
            throw new DIIllegalArgumentException(
                'DI.addModule(module, newModule): module [' + moduleType + '] doesn\'t extend [DI.Module].'
            );
        }

        if (newModuleType == null || !Module.class.isAssignableFrom(newModuleType)) {
            throw new DIIllegalArgumentException(
                'DI.addModule(module, newModule): newModule [' + newModuleType + '] doesn\'t extend [DI.Module].'
            );
        }
        GLOBAL_MODULES.moduleReplacements.put(moduleType, newModuleType);
        GLOBAL_MODULES.addFactory(newModuleType);
    }

    public static Module getModule(Type moduleType) {
        if (moduleType == null || !Module.class.isAssignableFrom(moduleType)) {
            throw new DIIllegalArgumentException(
                'DI.getModule(Type moduleType): moduleType [' + moduleType + '] doesn\'t extend [DI.Module].'
            );
        }
        return GLOBAL_MODULES.get(moduleType);
    }

    public static ServiceCollection services() {
        return new ServiceCollectionImpl();
    }

    // ==============
    // #region Module
    // Module system is provided for Salesforce to register and use services conveniently

    private class ModuleCollectionImpl extends Module implements ModuleCollection {
        private Map<Type, Type> moduleReplacements;
        private List<PrivateServiceCollection> modules;

        private ModuleCollectionImpl() {
            this.services = new ServiceCollectionImpl();
            this.provider = new ServiceProviderImpl(this.services.getDescriptors(), ModuleCollection.class.getName());
            this.moduleReplacements = new Map<Type, Type>();
            this.modules = new List<PrivateServiceCollection>();
        }

        private PrivateServiceCollection importedModules {
            get {
                return this.modules[this.modules.size() - 1];
            }
        }

        private void addImportedModules() {
            this.modules.add(new ServiceCollectionImpl());
        }

        private PrivateServiceCollection removeImportedModules() {
            return this.modules.remove(this.modules.size() - 1);
        }

        private Module get(Type moduleType) {
            if (this.moduleReplacements.containsKey(moduleType)) {
                moduleType = this.moduleReplacements.get(moduleType);
            }

            Module module = (Module) this.provider.getService(moduleType);
            if (module == null) {
                this.provider.removeService(moduleType);
                this.addFactory(moduleType);
            }
            return (Module) this.provider.getService(moduleType);
        }

        private void addFactory(Type moduleType) {
            this.services.addScopedFactory(moduleType.getName(), 'DI.ModuleFactory<' + moduleType + '>');
        }

        public ModuleCollection add(String moduleName) {
            Type moduleType = Type.forName(moduleName);
            if (moduleType == null || !Module.class.isAssignableFrom(moduleType)) {
                throw new DIIllegalArgumentException(
                    'DI.ModuleCollection.add(String moduleName): moduleName [' +
                        moduleName +
                        '] doesn\'t extend [DI.Module].'
                );
            }
            this.importedModules.addScoped(moduleName);
            return this;
        }

        public ModuleCollection add(String moduleName, String newModuleName) {
            Type moduleType = Type.forName(moduleName);
            if (moduleType == null || !Module.class.isAssignableFrom(moduleType)) {
                throw new DIIllegalArgumentException(
                    'DI.ModuleCollection.add(String moduleName, String newModuleName): moduleName [' +
                        moduleName +
                        '] doesn\'t extend [DI.Module].'
                );
            }

            Type newModuleType = Type.forName(newModuleName);
            if (newModuleType == null || !Module.class.isAssignableFrom(newModuleType)) {
                throw new DIIllegalArgumentException(
                    'DI.ModuleCollection.add(String moduleName, String newModuleName): newModuleName [' +
                        newModuleName +
                        '] doesn\'t extend [DI.Module].'
                );
            }
            this.moduleReplacements.put(moduleType, newModuleType);
            this.importedModules.addScoped(newModuleName, newModuleName);
            return this;
        }

        protected override void configure(ServiceCollection services) {
        }
    }

    public class ModuleFactory implements DI.ServiceFactory {
        public Object newInstance(Type moduleType, ServiceProvider serviceProvider) {
            ModuleCollectionImpl modules = GLOBAL_MODULES;

            Module module = (Module) moduleType.newInstance();
            module.services = new ServiceCollectionImpl();
            modules.addImportedModules();
            module.import(modules);

            for (ServiceDescriptor moduleDescriptor : modules.importedModules.getDescriptors()) {
                Type importedModuleType = Type.forName(moduleDescriptor.serviceName);
                Type importedNewModuleType = Type.forName(moduleDescriptor.implementationTypeName);
                if (importedModuleType != importedNewModuleType) {
                    modules.moduleReplacements.put(importedModuleType, importedNewModuleType);
                }
                Module importedModule = modules.get(importedModuleType);
                module.services.addServices(importedModule.services);
            }
            modules.removeImportedModules();

            module.configure(module.services);
            module.provider = new ServiceProviderImpl(module.services.getDescriptors(), moduleType.getName());
            return module;
        }
    }

    public class GlobalModule extends Module {
        private Set<ServiceDescriptor> uniqueDescriptors { get; set; }

        private GlobalModule() {
            this.services = new ServiceCollectionImpl();
            this.provider = new ServiceProviderImpl(this.services.getDescriptors(), GlobalModule.class.getName());
            this.uniqueDescriptors = new Set<ServiceDescriptor>();
        }

        protected override void configure(ServiceCollection services) {
        }

        private ServiceDescriptor add(ServiceDescriptor descriptor) {
            if (!this.uniqueDescriptors.contains(descriptor)) {
                System.debug(descriptor);
                this.uniqueDescriptors.add(descriptor);
                this.services.serviceDescriptors.add(descriptor);
            }
            return descriptor;
        }
    }

    public abstract class Module implements ServiceProvider {
        private ServiceCollectionImpl services { get; set; }
        private ServiceProviderImpl provider { get; set; }

        public Object getService(Type serviceType) {
            return this.provider.getService(serviceType);
        }

        public List<Object> getServices(Type serviceType) {
            return this.provider.getServices(serviceType);
        }

        protected virtual void import(ModuleCollection modules) {
        }

        protected abstract void configure(ServiceCollection services);
    }

    // #endregion
    // ==============

    // ==========================
    // #region Service Collection
    @TestVisible
    private enum ServiceLifetime {
        TransientLifeTime,
        SingletonLifeTime,
        ScopedLifeTime
    }

    @TestVisible
    private class ServiceDescriptor {
        private ServiceLifetime lifetime { get; private set; }
        private String serviceName { get; private set; }
        private String implementationTypeName { get; private set; }
        private String implementationFactoryTypeName { get; private set; }
        private Object implementationInstance { get; private set; }

        private ServiceDescriptor(String serviceName, String implementationTypeName, ServiceLifetime lifetime) {
            this.serviceName = serviceName.toUpperCase();
            this.implementationTypeName = implementationTypeName.toUpperCase();
            this.lifetime = lifetime;
        }

        private ServiceDescriptor(String serviceName, ServiceLifetime lifetime) {
            this.serviceName = serviceName.toUpperCase();
            this.lifetime = lifetime;
        }

        private ServiceDescriptor(
            String serviceName,
            String implementationTypeName,
            String factoryTypeName,
            ServiceLifetime lifetime
        ) {
            this.serviceName = serviceName.toUpperCase();
            this.implementationTypeName = implementationTypeName.toUpperCase();
            this.implementationFactoryTypeName = factoryTypeName.toUpperCase();
            this.lifetime = lifetime;
        }

        public Boolean equals(Object obj) {
            ServiceDescriptor that = (ServiceDescriptor) obj;

            return this.lifetime == that.lifetime &&
                this.serviceName == that.serviceName &&
                this.implementationTypeName == that.implementationTypeName &&
                this.implementationFactoryTypeName == that.implementationFactoryTypeName &&
                this.implementationInstance == that.implementationInstance;
        }
    }

    private virtual class ServiceCollectionImpl implements PrivateServiceCollection {
        private final List<ServiceDescriptor> serviceDescriptors;

        {
            serviceDescriptors = new List<ServiceDescriptor>();
        }

        public List<ServiceDescriptor> getDescriptors() {
            return this.serviceDescriptors;
        }

        public ServiceProvider buildServiceProvider() {
            return new ServiceProviderImpl(serviceDescriptors);
        }

        public ServiceCollection addTransient(String serviceName) {
            this.add(serviceName, serviceName, ServiceLifetime.TransientLifeTime);
            return this;
        }

        public ServiceCollection addTransient(String serviceName, String implementationTypeName) {
            this.add(serviceName, implementationTypeName, ServiceLifetime.TransientLifeTime);
            return this;
        }

        public ServiceCollection addTransientFactory(String serviceName, String factoryTypeName) {
            this.addFactory(serviceName, factoryTypeName, ServiceLifetime.TransientLifeTime);
            return this;
        }

        public ServiceCollection addTransient(String serviceName, Object instance) {
            this.addInstance(serviceName, instance, ServiceLifetime.TransientLifeTime);
            return this;
        }

        public ServiceCollection addScoped(String serviceName) {
            this.add(serviceName, serviceName, ServiceLifetime.ScopedLifeTime);
            return this;
        }

        public ServiceCollection addScoped(String serviceName, String implementationTypeName) {
            this.add(serviceName, implementationTypeName, ServiceLifetime.ScopedLifeTime);
            return this;
        }

        public ServiceCollection addScopedFactory(String serviceName, String factoryTypeName) {
            this.addFactory(serviceName, factoryTypeName, ServiceLifetime.ScopedLifeTime);
            return this;
        }

        public ServiceCollection addScoped(String serviceName, Object instance) {
            this.addInstance(serviceName, instance, ServiceLifetime.ScopedLifeTime);
            return this;
        }

        public ServiceCollection addSingleton(String serviceName) {
            this.add(serviceName, serviceName, ServiceLifetime.SingletonLifeTime);
            return this;
        }

        public ServiceCollection addSingleton(String serviceName, String implementationTypeName) {
            this.add(serviceName, implementationTypeName, ServiceLifetime.SingletonLifeTime);
            return this;
        }

        public ServiceCollection addSingletonFactory(String serviceName, String factoryTypeName) {
            this.addFactory(serviceName, factoryTypeName, ServiceLifetime.SingletonLifeTime);
            return this;
        }

        public ServiceCollection addSingleton(String serviceName, Object instance) {
            this.addInstance(serviceName, instance, ServiceLifetime.SingletonLifeTime);
            return this;
        }

        public ServiceCollection addServices(PrivateServiceCollection services) {
            this.serviceDescriptors.addAll(services.getDescriptors());
            return this;
        }

        private ServiceDescriptor add(String serviceName, String implementationTypeName, ServiceLifetime lifetime) {
            ServiceDescriptor descriptor = new ServiceDescriptor(serviceName, implementationTypeName, lifetime);
            this.serviceDescriptors.add(descriptor);
            if (lifetime == ServiceLifetime.SingletonLifeTime) {
                GLOBAL_MODULE.add(descriptor);
            }
            return descriptor;
        }

        private ServiceDescriptor addInstance(String serviceName, Object instance, ServiceLifetime lifetime) {
            ServiceDescriptor descriptor = new ServiceDescriptor(serviceName, lifetime);
            descriptor.implementationInstance = instance;
            this.serviceDescriptors.add(descriptor);
            if (lifetime == ServiceLifetime.SingletonLifeTime) {
                GLOBAL_MODULE.add(descriptor);
            }
            return descriptor;
        }

        private ServiceDescriptor addFactory(String serviceName, String factoryName, ServiceLifetime lifetime) {
            String factoryTypeName = factoryName;
            String implementationTypeName = serviceName;
            if (factoryName.endsWith('>')) {
                String[] names = factoryName.split('<');
                factoryTypeName = names[0];
                implementationTypeName = names[1].replace('>', '');
            }
            ServiceDescriptor descriptor = new ServiceDescriptor(
                serviceName,
                implementationTypeName,
                factoryTypeName,
                lifetime
            );
            this.serviceDescriptors.add(descriptor);
            if (lifetime == ServiceLifetime.SingletonLifeTime) {
                GLOBAL_MODULE.add(descriptor);
            }
            return descriptor;
        }
    }
    // #endregion
    // ==========================

    // =========================
    // #region Service Providers

    private class ServiceProviderImpl implements ServiceProvider, IServiceProviderEngineCallback {
        private ServiceProviderEngine engine { get; set; }
        protected Map<Type, IServiceRealizationFunc> realizedServices { get; private set; }
        private ServiceProviderEngineScope root { get; set; }
        private CallSiteFactory callSiteFactory { get; set; }
        private CallSiteRuntimeResolver callSiteResolver { get; set; }
        private String moduleName { get; set; }

        private ServiceProviderImpl(List<ServiceDescriptor> serviceDescriptors) {
            this.root = new ServiceProviderEngineScope(this, true);
            this.realizedServices = new Map<Type, IServiceRealizationFunc>();
            this.engine = RUNTIME_SERVICE_PROVIDER_ENGINE;

            this.callSiteFactory = new CallSiteFactory(serviceDescriptors);
            this.callSiteFactory.add(ServiceProvider.class, new ServiceProviderCallSite());
            this.callSiteResolver = CALL_SITE_RUNTIME_RESOLVER;
        }

        private ServiceProviderImpl(List<ServiceDescriptor> serviceDescriptors, String moduleName) {
            this(serviceDescriptors);
            this.moduleName = moduleName;
        }

        public Object getService(Type serviceType) {
            if (serviceType == null) {
                throw new DIIllegalArgumentException(
                    'DI.ServiceProvider.getService(Type serviceType): serviceType cannot be null.'
                );
            }

            return this.getService(serviceType, this.root);
        }

        public List<Object> getServices(Type serviceType) {
            if (serviceType == null) {
                throw new DIIllegalArgumentException(
                    'DI.ServiceProvider.getService(Type serviceType): serviceType cannot be null.'
                );
            }

            return this.getServices(serviceType, this.root);
        }

        public void onCreate(ServiceCallSite callSite) {
        }

        public void onResolve(Type serviceType, IServiceScope scope) {
        }

        private void removeService(Type serviceType) {
            this.callSiteFactory.callSiteCache.remove(serviceType);
            this.realizedServices.remove(serviceType);
        }

        private Object getService(Type serviceType, ServiceProviderEngineScope scope) {
            IServiceRealizationFunc realizedService;
            if (this.realizedServices.containsKey(serviceType)) {
                realizedService = this.realizedServices.get(serviceType);
            } else {
                realizedService = createServiceAccessor(serviceType);
                this.realizedServices.put(serviceType, realizedService);
            }
            this.onResolve(serviceType, scope);
            return realizedService.invoke(scope);
        }

        private IServiceRealizationFunc createServiceAccessor(Type serviceType) {
            ServiceCallSite callSite = this.callSiteFactory.getCallSite(serviceType);
            if (callSite != null) {
                this.onCreate(callSite);
                return this.engine.realizeService(callSite);
            }

            return new NullServiceRealizationFunc();
        }

        private List<Object> getServices(Type serviceType, ServiceProviderEngineScope scope) {
            Type serviceListType = Type.forName('List<' + serviceType.getName() + '>');
            List<Object> services = (List<Object>) serviceListType.newInstance();
            for (Object service : (List<Object>) this.getService(serviceListType, scope)) {
                services.add(service);
            }
            return services;
        }

        private IServiceScope createScope() {
            return new ServiceProviderEngineScope(this, false);
        }
    }

    private class ServiceProviderEngineScope implements IServiceScope, ServiceProvider {
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
            return this.rootProvider.getService(serviceType, this);
        }

        public List<Object> getServices(Type serviceType) {
            return this.rootProvider.getServices(serviceType, this);
        }

        public IServiceScope createScope() {
            return this.rootProvider.createScope();
        }
    }

    private abstract class ServiceProviderEngine {
        protected abstract IServiceRealizationFunc realizeService(ServiceCallSite callSite);
    }

    // Reference RUNTIME_SERVICE_PROVIDER_ENGINE as the singleton instance;
    private class RuntimeServiceProviderEngine extends ServiceProviderEngine {
        protected override IServiceRealizationFunc realizeService(ServiceCallSite callSite) {
            return new RuntimeServiceRealizationFunc(callSite);
        }
    }

    private class RuntimeServiceRealizationFunc implements IServiceRealizationFunc {
        private ServiceCallSite callSite { get; set; }

        private RuntimeServiceRealizationFunc(ServiceCallSite callSite) {
            this.callSite = callSite;
        }

        public Object invoke(ServiceProviderEngineScope scope) {
            return CALL_SITE_RUNTIME_RESOLVER.resolve(callSite, scope);
        }
    }

    private class NullServiceRealizationFunc implements IServiceRealizationFunc {
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

        private CallSiteRuntimeResolver() {
        }

        private CallSiteRuntimeResolver(ServiceProviderEngineScope rootScope) {
            this.rootScope = rootScope;
        }

        private Object resolve(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            return visitCallSite(callSite, scope);
        }

        protected override Object visitRootCache(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            // ServiceProviderEngineScope rootScope = scope;
            // if (!scope.isRootScope) {
            //     rootScope = scope.rootProvider.root;
            // }
            // Map<ServiceCacheKey, Object> resolvedServices = rootScope.resolvedServices;
            // if (!resolvedServices.containsKey(callSite.cache.key)) {
            //     resolvedServices.put(callSite.cache.key, visitCallSiteMain(callSite, rootScope));
            // }
            // return resolvedServices.get(callSite.cache.key);

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
            switch on callSite.kind {
                when Factory {
                    return ((FactoryCallSite) callSite).factory.newInstance(callSite.implementationType, scope);
                }
                when IEnumerable {
                    List<Object> services = new List<Object>();
                    for (ServiceCallSite serviceCallSite : ((IEnumerableCallSite) callSite).serviceCallSites) {
                        services.add(this.visitCallSite(serviceCallSite, scope));
                    }
                    return services;
                }
                when Constructor {
                    return ((ConstructorCallSite) callSite).implementationType.newInstance();
                }
                when Constant {
                    return ((ConstantCallSite) callSite).defaultValue;
                }
                when ServiceProvider {
                    return scope;
                }
                when else {
                    throw new NoSuchElementException();
                }
            }
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
        private final Integer DEFAULT_SLOT = 0;
        private List<ServiceDescriptor> serviceDescriptors { get; set; }
        private Map<Type, ServiceCallSite> callSiteCache { get; set; }

        private CallSiteFactory(List<ServiceDescriptor> serviceDescriptors) {
            this.serviceDescriptors = serviceDescriptors;
            callSiteCache = new Map<Type, ServiceCallSite>();
        }

        private void add(Type serviceType, ServiceCallSite callSite) {
            this.callSiteCache.put(serviceType, callSite);
        }

        private ServiceCallSite getCallSite(Type serviceType) {
            if (!callSiteCache.containsKey(serviceType)) {
                callSiteCache.put(serviceType, createCallSite(serviceType));
            }
            return callSiteCache.get(serviceType);
        }

        private ServiceCallSite createCallSite(Type serviceType) {
            if ((List<Object>.class).isAssignableFrom(serviceType)) {
                return tryCreateEnumerable(serviceType);
            } else {
                return tryCreateExact(serviceType);
            }
        }

        private ServiceCallSite tryCreateExact(Type serviceType) {
            ServiceCallSite callSite;
            for (Integer i = this.serviceDescriptors.size(); i > 0; i--) {
                callSite = tryCreateExact(serviceDescriptors[i - 1], serviceType, this.DEFAULT_SLOT);
                if (callSite != null) {
                    break;
                }
            }
            return callSite;
        }

        private ServiceCallSite tryCreateExact(ServiceDescriptor descriptor, Type serviceType, Integer slot) {
            if (descriptor.serviceName == serviceType.getName().toUpperCase()) {
                ServiceCallSite callSite;
                ResultCache cache = new ResultCache(descriptor.Lifetime, serviceType, slot);
                if (descriptor.implementationInstance != null) {
                    callSite = new ConstantCallSite(serviceType, descriptor.implementationInstance);
                } else if (descriptor.implementationFactoryTypeName != null) {
                    callSite = new FactoryCallSite(
                        cache,
                        serviceType,
                        descriptor.implementationTypeName,
                        descriptor.implementationFactoryTypeName
                    );
                } else if (descriptor.implementationTypeName != null) {
                    callSite = new ConstructorCallSite(cache, serviceType, descriptor.implementationTypeName);
                } else {
                    throw new NoSuchElementException();
                }

                return callSite;
            }
            return null;
        }

        private ServiceCallSite tryCreateEnumerable(Type serviceListType) {
            String serviceName = serviceListType.getName().replace('List<', '').replace('>', '').toUpperCase();
            Type serviceType = Type.forName(serviceName);

            List<ServiceDescriptor> descriptors = new List<ServiceDescriptor>();
            for (ServiceDescriptor serviceDescriptor : this.serviceDescriptors) {
                if (serviceDescriptor.serviceName == serviceName) {
                    descriptors.add(serviceDescriptor);
                }
            }

            List<ServiceCallSite> serviceCallSites = new List<ServiceCallSite>();
            for (Integer i = descriptors.size(); i > 0; i--) {
                Integer slot = descriptors.size() - i;
                ServiceCallSite callSite = tryCreateExact(descriptors[i - 1], serviceType, slot);
                if (callSite != null) {
                    serviceCallSites.add(callSite);
                }
            }

            return new IEnumerableCallSite(serviceType, serviceCallSites);
        }
    }

    private enum CallSiteKind {
        Factory,
        Constant,
        Constructor,
        IEnumerable,
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

    private abstract class ServiceCallSite {
        protected Type serviceType { get; set; }
        protected Type implementationType { get; set; }
        protected CallSiteKind kind { get; set; }
        protected ResultCache cache { get; set; }

        private ServiceCallSite(ResultCache cache) {
            this.cache = cache;
        }
    }

    private class ConstructorCallSite extends ServiceCallSite {
        private ConstructorCallSite(ResultCache cache, type serviceType, String implementationTypeName) {
            super(cache);
            this.serviceType = serviceType;
            this.implementationType = Type.forName(implementationTypeName);
            this.kind = CallSiteKind.Constructor;

            if (!serviceType.isAssignableFrom(this.implementationType)) {
                throw new DITypeException(
                    'DI registered service type [' +
                        this.implementationType +
                        '] doesn\'t implement [' +
                        serviceType +
                        '].'
                );
            }
        }
    }

    private class FactoryCallSite extends ServiceCallSite {
        private ServiceFactory factory { get; set; }

        private FactoryCallSite(
            ResultCache cache,
            type serviceType,
            String implementationTypeName,
            String factoryTypeName
        ) {
            super(cache);
            Type factoryType = Type.forName(factoryTypeName);
            if (!ServiceFactory.class.isAssignableFrom(factoryType)) {
                throw new DITypeException(
                    'DI registered factory type [' + factoryType + '] doesn\'t implement [DI.ServiceFactory].'
                );
            }

            Type implementationType = Type.forName(implementationTypeName);
            if (!serviceType.isAssignableFrom(implementationType)) {
                throw new DITypeException(
                    'DI registered factory return type [' +
                        implementationType +
                        '] doesn\'t implement [' +
                        serviceType +
                        '].'
                );
            }

            this.serviceType = serviceType;
            this.implementationType = implementationType;
            this.factory = (ServiceFactory) factoryType.newInstance();
            this.kind = CallSiteKind.Factory;
        }
    }

    private class ConstantCallSite extends ServiceCallSite {
        private Object defaultValue { get; set; }

        private ConstantCallSite(type serviceType, Object defaultValue) {
            super(RESULT_CACHE_NONE);
            this.serviceType = serviceType;
            this.defaultValue = defaultValue;
            this.kind = CallSiteKind.Constant;
        }
    }

    private class ServiceProviderCallSite extends ServiceCallSite {
        private ServiceProviderCallSite() {
            super(RESULT_CACHE_NONE);
            this.serviceType = ServiceProvider.class;
            this.implementationType = ServiceProviderImpl.class;
            this.kind = CallSiteKind.ServiceProvider;
        }
    }

    private class IEnumerableCallSite extends ServiceCallSite {
        private Type itemType { get; set; }
        private List<ServiceCallSite> serviceCallSites { get; set; }

        private IEnumerableCallSite(Type itemType, List<ServiceCallSite> serviceCallSites) {
            super(RESULT_CACHE_NONE);
            this.itemType = itemType;
            this.serviceCallSites = serviceCallSites;
            this.kind = CallSiteKind.IEnumerable;
        }
    }

    private class ResultCache {
        private CallSiteResultCacheLocation location { get; set; }
        private ServiceCacheKey key { get; set; }

        private ResultCache(CallSiteResultCacheLocation lifetime, ServiceCacheKey cacheKey) {
            Location = lifetime;
            Key = cacheKey;
        }

        private ResultCache(ServiceLifetime lifetime, type serviceType, Integer slot) {
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

            this.key = new ServiceCacheKey(serviceType, slot);
        }
    }

    private class ServiceCacheKey {
        private Type serviceType { get; set; }
        private Integer slot { get; set; }

        private ServiceCacheKey(Type serviceType, Integer slot) {
            this.serviceType = serviceType;
            this.slot = slot;
        }

        public Boolean equals(Object obj) {
            ServiceCacheKey other = (ServiceCacheKey) obj;
            return this.serviceType == other.serviceType && this.slot == other.slot;
        }

        public Integer hashCode() {
            return ((this.serviceType == null ? 23 : this.serviceType.hashCode()) * 397) ^ this.slot;
        }
    }

    // #endregion
    // ==================

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

    // ==================
    // #region Interfaces
    public interface ServiceFactory {
        Object newInstance(Type serviceType, ServiceProvider serviceProvider);
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
        ServiceCollection addScoped(String serviceName, Object instance);
        ServiceCollection addScoped(String serviceName, String implementationTypeName);
        ServiceCollection addScopedFactory(String serviceName, String factoryTypeName);
    }

    private interface PrivateServiceCollection extends ServiceCollection {
        List<ServiceDescriptor> getDescriptors();
        ServiceCollection addServices(PrivateServiceCollection services);
    }

    public interface ServiceProvider {
        Object getService(Type serviceType);
        List<Object> getServices(Type serviceType);
    }

    private interface IServiceScope {
        ServiceProvider getServiceProvider();
    }

    private interface IServiceScopeFactory {
        IServiceScope createScope();
    }

    private interface IServiceProviderEngineCallback {
        void onCreate(ServiceCallSite callSite);
        void onResolve(Type serviceType, IServiceScope scope);
    }

    private interface IServiceRealizationFunc {
        Object invoke(ServiceProviderEngineScope scope);
    }

    public interface ModuleCollection {
        ModuleCollection add(String moduleName);
        ModuleCollection add(String moduleName, String newModuleName);
    }

    // #endregion
    // ==================
}
