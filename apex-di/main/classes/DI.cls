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
        new ServiceCacheKey(null, null, 0)
    );
    private static final CallSiteRuntimeResolver CALL_SITE_RUNTIME_RESOLVER;
    private static final RuntimeServiceProviderEngine RUNTIME_SERVICE_PROVIDER_ENGINE = new RuntimeServiceProviderEngine();

    private static final ModuleCollectionImpl GLOBAL_MODULES = new ModuleCollectionImpl();
    @TestVisible
    private static final RootModule ROOT_MODULE;

    static {
        ROOT_MODULE = new RootModule();
        GLOBAL_MODULES.services.addScoped(RootModule.class.getName(), ROOT_MODULE);
        CALL_SITE_RUNTIME_RESOLVER = new CallSiteRuntimeResolver(ROOT_MODULE.provider.root);
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
        private List<IServiceCollection> modules;

        private ModuleCollectionImpl() {
            this.services = new ServiceCollectionImpl();
            this.provider = new ServiceProviderImpl(this.services.getDescriptors(), ModuleCollection.class.getName());
            this.moduleReplacements = new Map<Type, Type>();
            this.modules = new List<IServiceCollection>();
        }

        private IServiceCollection importedModules {
            get {
                return this.modules[this.modules.size() - 1];
            }
        }

        private void addImportedModules() {
            this.modules.add(new ServiceCollectionImpl());
        }

        private IServiceCollection removeImportedModules() {
            return this.modules.remove(this.modules.size() - 1);
        }

        private Module get(Type moduleType) {
            if (this.moduleReplacements.containsKey(moduleType)) {
                moduleType = this.moduleReplacements.get(moduleType);
            }

            Module module = (Module) this.provider.getService(moduleType);
            if (module == null) {
                this.removeService(moduleType);
                this.addFactory(moduleType);
            }
            return (Module) this.provider.getService(moduleType);
        }

        // only for module registration
        private void removeService(Type serviceType) {
            String serviceName = serviceType.getName().toUpperCase();
            this.provider.callSiteFactory.callSiteCache.remove(serviceName);
            this.provider.realizedServices.remove(serviceName);
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

            for (ServiceDescriptor moduleDescriptor : modules.importedModules.getDescriptors().values()) {
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

    private class RootModule extends Module {
        private RootModule() {
            this.services = new ServiceCollectionImpl();
            this.provider = new ServiceProviderImpl(this.services.getDescriptors(), RootModule.class.getName());
        }

        protected override void configure(ServiceCollection services) {
        }

        private ServiceDescriptor add(ServiceDescriptor descriptor) {
            this.services.serviceDescriptors.put(descriptor.serviceName, descriptor);
            return descriptor;
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
        private String serviceName { get; private set; }
        private String implementationTypeName { get; private set; }
        private String implementationFactoryTypeName { get; private set; }
        private Object implementationInstance { get; private set; }
        private ServiceLifetime lifetime { get; private set; }

        @TestVisible
        private ServiceDescriptor(String serviceName, String implementationTypeName, ServiceLifetime lifetime) {
            this.serviceName = serviceName.toUpperCase();
            this.implementationTypeName = implementationTypeName.toUpperCase();
            this.lifetime = lifetime;
        }

        @TestVisible
        private ServiceDescriptor(String serviceName, ServiceLifetime lifetime) {
            this.serviceName = serviceName.toUpperCase();
            this.lifetime = lifetime;
        }

        @TestVisible
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
    }

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

        private ServiceCollection addScoped(String serviceName, Object instance) {
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

        public ServiceCollection addServices(IServiceCollection services) {
            this.serviceDescriptors.putAll(services.getDescriptors());
            return this;
        }

        private ServiceDescriptor add(String serviceName, String implementationTypeName, ServiceLifetime lifetime) {
            ServiceDescriptor descriptor = new ServiceDescriptor(serviceName, implementationTypeName, lifetime);
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            if (lifetime == ServiceLifetime.SingletonLifeTime) {
                ROOT_MODULE.add(descriptor);
            }
            return descriptor;
        }

        private ServiceDescriptor addInstance(String serviceName, Object instance, ServiceLifetime lifetime) {
            ServiceDescriptor descriptor = new ServiceDescriptor(serviceName, lifetime);
            descriptor.implementationInstance = instance;
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            if (lifetime == ServiceLifetime.SingletonLifeTime) {
                ROOT_MODULE.add(descriptor);
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
            this.serviceDescriptors.put(descriptor.serviceName, descriptor);
            if (lifetime == ServiceLifetime.SingletonLifeTime) {
                ROOT_MODULE.add(descriptor);
            }
            return descriptor;
        }
    }
    // #endregion
    // ==========================

    // =========================
    // #region Service Providers

    private class ServiceProviderImpl implements ServiceProvider, ServiceProviderEngineCallback {
        private ServiceProviderEngine engine { get; set; }
        protected Map<String, ServiceRealizationFunc> realizedServices { get; private set; }
        private ServiceProviderEngineScope root { get; set; }
        private CallSiteFactory callSiteFactory { get; set; }
        private CallSiteRuntimeResolver callSiteResolver { get; set; }
        private String moduleName { get; set; }

        private ServiceProviderImpl(Map<String, ServiceDescriptor> serviceDescriptors) {
            this.root = new ServiceProviderEngineScope(this, true);
            this.realizedServices = new Map<String, ServiceRealizationFunc>();
            this.engine = RUNTIME_SERVICE_PROVIDER_ENGINE;

            this.callSiteFactory = new CallSiteFactory(serviceDescriptors);
            this.callSiteFactory.add(ServiceProvider.class.getName().toUpperCase(), new ServiceProviderCallSite());
            this.callSiteResolver = CALL_SITE_RUNTIME_RESOLVER;
        }

        private ServiceProviderImpl(Map<String, ServiceDescriptor> serviceDescriptors, String moduleName) {
            this(serviceDescriptors);
            this.moduleName = moduleName;
        }

        public Object getService(Type serviceType) {
            if (serviceType == null) {
                throw new DIIllegalArgumentException(
                    'DI.ServiceProvider.getService(Type serviceType): serviceType cannot be null.'
                );
            }

            return this.getService(serviceType.getName(), this.root);
        }

        public Object getService(String serviceName) {
            if (String.isBlank(serviceName)) {
                throw new DIIllegalArgumentException(
                    'DI.ServiceProvider.getService(String serviceName): serviceName cannot be blank.'
                );
            }
            return this.getService(serviceName, this.root);
        }

        public void onCreate(ServiceCallSite callSite) {
        }

        public void onResolve(String serviceType, ServiceScope scope) {
        }

        private Object getService(String serviceName, ServiceProviderEngineScope scope) {
            serviceName = serviceName.replace(' ', '').toUpperCase(); // formalize service name
            ServiceRealizationFunc realizedService;
            if (this.realizedServices.containsKey(serviceName)) {
                realizedService = this.realizedServices.get(serviceName);
            } else {
                realizedService = createServiceAccessor(serviceName);
                this.realizedServices.put(serviceName, realizedService);
            }
            this.onResolve(serviceName, scope);
            return realizedService.invoke(scope);
        }

        private ServiceRealizationFunc createServiceAccessor(String serviceName) {
            ServiceCallSite callSite = this.callSiteFactory.getCallSite(serviceName);
            if (callSite != null) {
                this.onCreate(callSite);
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
                throw new DIIllegalArgumentException(
                    'DI.ServiceProvider.getService(Type serviceType): serviceType cannot be null.'
                );
            }
            return this.rootProvider.getService(serviceType.getName(), this);
        }

        public Object getService(String serviceName) {
            if (String.isBlank(serviceName)) {
                throw new DIIllegalArgumentException(
                    'DI.ServiceProvider.getService(String serviceName): serviceName cannot be blank.'
                );
            }
            return this.rootProvider.getService(serviceName, this);
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
                    FactoryCallSite factoryCallSite = (FactoryCallSite) callSite;
                    IServiceFactory factory = factoryCallSite.factory;
                    if (factory instanceof ServiceFactory) {
                        return ((ServiceFactory) factory).newInstance(callSite.implementationType, scope);
                    } else if (factory instanceof GenericServiceFactory) {
                        return ((GenericServiceFactory) factory)
                            .newInstance(callSite.implementationType, factoryCallSite.genericTypes, scope);
                    }
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
            }
            throw new NoSuchElementException();
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

        private ServiceCallSite createCallSite(String serviceName) {
            List<String> genericTypes = new List<String>();

            if (serviceName.endsWith('>')) {
                List<String> splits = serviceName.replace('>', '').split('<');
                serviceName = splits[0];
                for (String genericName : splits[1].split(',')) {
                    genericTypes.add(genericName);
                }
            }

            return tryCreateExact(
                this.serviceDescriptors.get(serviceName),
                serviceName,
                genericTypes,
                this.DEFAULT_SLOT
            );
        }

        private ServiceCallSite tryCreateExact(
            ServiceDescriptor descriptor,
            String serviceName,
            List<String> genericTypes,
            Integer slot
        ) {
            ServiceCallSite callSite;

            if (descriptor != null) {
                ResultCache cache = new ResultCache(descriptor.Lifetime, serviceName, genericTypes, slot);
                if (descriptor.implementationInstance != null) {
                    callSite = new ConstantCallSite(serviceName, descriptor.implementationInstance);
                } else if (descriptor.implementationFactoryTypeName != null) {
                    callSite = new FactoryCallSite(
                        cache,
                        serviceName,
                        genericTypes,
                        descriptor.implementationTypeName,
                        descriptor.implementationFactoryTypeName
                    );
                } else if (descriptor.implementationTypeName != null) {
                    callSite = new ConstructorCallSite(cache, serviceName, descriptor.implementationTypeName);
                } else {
                    throw new NoSuchElementException();
                }
            }

            return callSite;
        }
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

    private abstract class ServiceCallSite {
        protected String serviceName { get; set; }
        protected Type implementationType { get; set; }
        protected CallSiteKind kind { get; set; }
        protected ResultCache cache { get; set; }

        private ServiceCallSite(ResultCache cache) {
            this.cache = cache;
        }
    }

    private class ConstructorCallSite extends ServiceCallSite {
        private ConstructorCallSite(ResultCache cache, String serviceName, String implementationTypeName) {
            super(cache);
            this.serviceName = serviceName;
            this.implementationType = Type.forName(implementationTypeName);
            this.kind = CallSiteKind.Constructor;
        }
    }

    private class FactoryCallSite extends ServiceCallSite {
        private IServiceFactory factory { get; set; }
        private List<String> genericTypes { get; set; }

        private FactoryCallSite(
            ResultCache cache,
            String serviceName,
            List<String> genericTypes,
            String implementationTypeName,
            String factoryTypeName
        ) {
            super(cache);
            Type factoryType = Type.forName(factoryTypeName);
            if (
                !ServiceFactory.class.isAssignableFrom(factoryType) &&
                !GenericServiceFactory.class.isAssignableFrom(factoryType)
            ) {
                throw new DITypeException(
                    'DI registered factory type [' +
                        factoryType +
                        '] doesn\'t implement [DI.ServiceFactory] or [DI.GenericServiceFactory].'
                );
            }

            this.serviceName = serviceName;
            this.genericTypes = genericTypes;
            this.implementationType = Type.forName(implementationTypeName);
            this.factory = (IServiceFactory) factoryType.newInstance();
            this.kind = CallSiteKind.Factory;
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
    }

    private class ServiceProviderCallSite extends ServiceCallSite {
        private ServiceProviderCallSite() {
            super(RESULT_CACHE_NONE);
            this.serviceName = ServiceProvider.class.getName().toUpperCase();
            this.implementationType = ServiceProviderImpl.class;
            this.kind = CallSiteKind.ServiceProvider;
        }
    }

    private class ResultCache {
        private CallSiteResultCacheLocation location { get; set; }
        private ServiceCacheKey key { get; set; }

        private ResultCache(CallSiteResultCacheLocation lifetime, ServiceCacheKey cacheKey) {
            Location = lifetime;
            Key = cacheKey;
        }

        private ResultCache(ServiceLifetime lifetime, String serviceName, List<String> genericTypes, Integer slot) {
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

            this.key = new ServiceCacheKey(serviceName, genericTypes, slot);
        }
    }

    private class ServiceCacheKey {
        private String serviceName { get; set; }
        private List<String> genericTypes { get; set; }
        private Integer slot { get; set; }

        private ServiceCacheKey(String serviceName, List<String> genericTypes, Integer slot) {
            this.serviceName = serviceName;
            this.genericTypes = genericTypes;
            this.slot = slot;
        }

        public Boolean equals(Object obj) {
            if (this === obj) {
                return true;
            }

            ServiceCacheKey that = (ServiceCacheKey) obj;
            return this.serviceName == that.serviceName &&
                this.genericTypes == that.genericTypes &&
                this.slot == that.slot;
        }

        public Integer hashCode() {
            Integer hashCode = this.serviceName == null ? 23 : this.serviceName.hashCode();
            hashCode = (hashCode * 397) ^ (this.genericTypes == null ? 23 : this.genericTypes.hashCode());
            hashCode = (hashCode * 397) ^ this.slot;
            return hashCode;
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
    private interface IServiceFactory {
    }

    public interface ServiceFactory extends IServiceFactory {
        Object newInstance(Type serviceType, ServiceProvider serviceProvider);
    }

    public interface GenericServiceFactory extends IServiceFactory {
        Object newInstance(Type serviceType, List<String> genericTypes, ServiceProvider serviceProvider);
    }

    public interface ServiceCollection {
        ServiceProvider buildServiceProvider();

        ServiceCollection addTransient(String serviceTypeName);
        ServiceCollection addTransient(String serviceTypeName, String implementationTypeName);
        ServiceCollection addTransientFactory(String serviceTypeName, String factoryTypeName);

        ServiceCollection addSingleton(String serviceTypeName);
        ServiceCollection addSingleton(String serviceTypeName, Object instance);
        ServiceCollection addSingleton(String serviceTypeName, String implementationTypeName);
        ServiceCollection addSingletonFactory(String serviceTypeName, String factoryTypeName);

        ServiceCollection addScoped(String serviceName);
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

    private interface ServiceProviderEngineCallback {
        void onCreate(ServiceCallSite callSite);
        void onResolve(String serviceType, ServiceScope scope);
    }

    private interface ServiceRealizationFunc {
        Object invoke(ServiceProviderEngineScope scope);
    }

    public interface ModuleCollection {
        ModuleCollection add(String moduleName);
        ModuleCollection add(String moduleName, String newModuleName);
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

