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
    private static final CallSiteRuntimeResolver CALL_SITE_RUNTIME_RESOLVER = new CallSiteRuntimeResolver();
    private static final RuntimeServiceProviderEngine RUNTIME_SERVICE_PROVIDER_ENGINE = new RuntimeServiceProviderEngine();
    private static final Map<Type, Module> MODULE_CACHE = new Map<Type, Module>();
    private static final Map<Type, Type> MODULE_REPLACEMENT = new Map<Type, Type>();

    // ==============
    // #region Module
    // Module is provided specifically for Salesforce to register and use services conveniently
    public abstract class Module implements ServiceProvider {
        private ServiceCollection services;
        private ServiceProvider provider;

        public Object getService(Type serviceType) {
            return this.provider.getService(serviceType);
        }

        public List<Object> getServices(Type serviceType) {
            return this.provider.getServices(serviceType);
        }

        public Object getService(String serviceName) {
            return this.provider.getService(serviceName);
        }

        public List<Object> getServices(String serviceName) {
            return this.provider.getServices(serviceName);
        }

        protected virtual void import(List<String> modules) {
        }

        protected abstract void build(ServiceCollection services);
    }

    public static void setModule(Type replacedModuleType, Type moduleType) {
        if (replacedModuleType == null || !Module.class.isAssignableFrom(replacedModuleType)) {
            throw new IllegalArgumentException(
                'DI.setModule(Type replacedModuleType, Type moduleType): replacedModuleType [' +
                    replacedModuleType +
                    '] doesn\'t extend [DI.Module].'
            );
        }

        if (moduleType == null || !Module.class.isAssignableFrom(moduleType)) {
            throw new IllegalArgumentException(
                'DI.setModule(Type replacedModuleType, Type moduleType): moduleType [' +
                    moduleType +
                    '] doesn\'t extend [DI.Module].'
            );
        }
        MODULE_REPLACEMENT.put(replacedModuleType, moduleType);
    }

    public static Module getModule(Type replacedModuleType) {
        if (MODULE_REPLACEMENT.containsKey(replacedModuleType)) {
            replacedModuleType = MODULE_REPLACEMENT.get(replacedModuleType);
        }

        if (replacedModuleType == null || !Module.class.isAssignableFrom(replacedModuleType)) {
            throw new IllegalArgumentException(
                'DI.getModule(Type replacedModuleType): replacedModuleType [' +
                    replacedModuleType +
                    '] doesn\'t extend [DI.Module].'
            );
        }

        if (!MODULE_CACHE.containsKey(replacedModuleType)) {
            Module module = (Module) replacedModuleType.newInstance();
            module.services = new ServiceCollectionImpl();
            List<String> moduleNames = new List<String>();
            module.import(moduleNames);
            for (String importedModuleName : moduleNames) {
                Type importedModuleType = Type.forName(importedModuleName);
                Module importedModule = getModule(importedModuleType);
                module.services.addCollection(importedModule.services);
            }

            module.build(module.services);
            module.provider = module.services.buildServiceProvider();
            MODULE_CACHE.put(replacedModuleType, module);
        }
        return MODULE_CACHE.get(replacedModuleType);
    }

    public static ServiceCollection services() {
        return new ServiceCollectionImpl();
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
    }

    private class ServiceCollectionImpl implements ServiceCollection {
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
            add(serviceName, serviceName, ServiceLifetime.TransientLifeTime);
            return this;
        }

        public ServiceCollection addTransient(String serviceName, String implementationTypeName) {
            add(serviceName, implementationTypeName, ServiceLifetime.TransientLifeTime);
            return this;
        }

        public ServiceCollection addTransientFactory(String serviceName, String factoryTypeName) {
            addFactory(serviceName, factoryTypeName, ServiceLifetime.TransientLifeTime);
            return this;
        }

        public ServiceCollection addTransient(String serviceName, Object implementationInstance) {
            addInstance(serviceName, implementationInstance, ServiceLifetime.TransientLifeTime);
            return this;
        }

        public ServiceCollection addSingleton(String serviceName) {
            add(serviceName, serviceName, ServiceLifetime.SingletonLifeTime);
            return this;
        }

        public ServiceCollection addSingleton(String serviceName, String implementationTypeName) {
            add(serviceName, implementationTypeName, ServiceLifetime.SingletonLifeTime);
            return this;
        }

        public ServiceCollection addSingletonFactory(String serviceName, String factoryTypeName) {
            addFactory(serviceName, factoryTypeName, ServiceLifetime.SingletonLifeTime);
            return this;
        }

        public ServiceCollection addSingleton(String serviceName, Object implementationInstance) {
            addInstance(serviceName, implementationInstance, ServiceLifetime.SingletonLifeTime);
            return this;
        }

        public ServiceCollection addCollection(ServiceCollection services) {
            this.serviceDescriptors.addAll(services.getDescriptors());
            return this;
        }

        private ServiceDescriptor add(String serviceName, String implementationTypeName, ServiceLifetime lifetime) {
            ServiceDescriptor descriptor = new ServiceDescriptor(serviceName, implementationTypeName, lifetime);
            this.serviceDescriptors.add(descriptor);
            return descriptor;
        }

        private ServiceDescriptor addInstance(
            String serviceName,
            Object implementationInstance,
            ServiceLifetime lifetime
        ) {
            ServiceDescriptor descriptor = new ServiceDescriptor(serviceName, lifetime);
            descriptor.implementationInstance = implementationInstance;
            this.serviceDescriptors.add(descriptor);
            return descriptor;
        }

        private ServiceDescriptor addFactory(String serviceName, String factoryTypeName, ServiceLifetime lifetime) {
            ServiceDescriptor descriptor = new ServiceDescriptor(serviceName, lifetime);
            descriptor.implementationFactoryTypeName = factoryTypeName;
            this.serviceDescriptors.add(descriptor);
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
            IServiceProviderEngineCallback callback = this;
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
                throw new IllegalArgumentException(
                    'DI.ServiceProvider.getService(Type serviceType): serviceType cannot be null.'
                );
            }

            return this.getService(serviceType, this.root);
        }

        public List<Object> getServices(Type serviceType) {
            if (serviceType == null) {
                throw new IllegalArgumentException(
                    'DI.ServiceProvider.getService(Type serviceType): serviceType cannot be null.'
                );
            }

            return this.getServices(serviceType, this.root);
        }

        public Object getService(String serviceName) {
            Type serviceType = Type.forName(serviceName);
            if (serviceType == null) {
                throw new IllegalArgumentException(
                    'DI.ServiceProvider.getService(String serviceName): serviceName "' +
                        serviceName +
                        '" is not a valid type name.'
                );
            }
            return this.getService(serviceType, this.root);
        }

        public List<Object> getServices(String serviceName) {
            Type serviceType = Type.forName(serviceName);
            if (serviceType == null) {
                throw new IllegalArgumentException(
                    'DI.ServiceProvider.getServices(String serviceName): serviceName "' +
                        serviceName +
                        '" is not a valid type name.'
                );
            }
            return this.getServices(serviceType, this.root);
        }

        public void onCreate(ServiceCallSite callSite) {
        }

        public void onResolve(Type serviceType, IServiceScope scope) {
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
            ServiceCallSite callSite = this.callSiteFactory.GetCallSite(serviceType);
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
    }

    private class ServiceProviderEngineScope implements IServiceScope, ServiceProvider {
        private Map<ServiceCacheKey, Object> resolvedServices { get; set; } // ! Used as singleton cache
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

        public Object getService(String serviceName) {
            Type serviceType = Type.forName(serviceName);
            return this.rootProvider.getService(serviceType, this);
        }

        public List<Object> getServices(String serviceName) {
            Type serviceType = Type.forName(serviceName);
            return this.rootProvider.getServices(serviceType, this);
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
        private Object resolve(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            return visitCallSite(callSite, scope);
        }

        protected override Object visitRootCache(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
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
                    return ((FactoryCallSite) callSite).factory.newInstance(scope);
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
                when ServiceProviderImpl {
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
                    callSite = new FactoryCallSite(cache, serviceType, descriptor.implementationFactoryTypeName);
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
        ServiceProviderImpl,
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
                throw new TypeException(
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

        private FactoryCallSite(ResultCache cache, type serviceType, String factoryTypeName) {
            super(cache);
            Type factoryType = Type.forName(factoryTypeName);
            if (!ServiceFactory.class.isAssignableFrom(factoryType)) {
                throw new TypeException(
                    'DI registered factory type [' + factoryType + '] doesn\'t implement [DI.ServiceFactory].'
                );
            }

            this.serviceType = serviceType;
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
            this.kind = CallSiteKind.ServiceProviderImpl;
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
    // #region Interfaces

    // Start: expose interface without I prefix
    public interface ServiceFactory {
        Object newInstance(ServiceProvider serviceProvider);
    }

    public interface ServiceCollection {
        List<ServiceDescriptor> getDescriptors();
        ServiceProvider buildServiceProvider();
        ServiceCollection addTransient(String serviceTypeName);
        ServiceCollection addTransient(String serviceTypeName, Object instance);
        ServiceCollection addTransient(String serviceTypeName, String implementationTypeName);
        ServiceCollection addTransientFactory(String serviceTypeName, String factoryTypeName);
        ServiceCollection addSingleton(String serviceTypeName);
        ServiceCollection addSingleton(String serviceTypeName, Object instance);
        ServiceCollection addSingleton(String serviceTypeName, String implementationTypeName);
        ServiceCollection addSingletonFactory(String serviceTypeName, String factoryTypeName);
        ServiceCollection addCollection(ServiceCollection services);
    }

    public interface ServiceProvider {
        Object getService(Type serviceType);
        Object getService(String serviceName);
        List<Object> getServices(Type serviceType); // In dotnet this is implemented in an extension method
        List<Object> getServices(String serviceName);
    }
    // End: expose interface without I prefix

    interface IServiceScope {
        ServiceProvider getServiceProvider();
    }

    interface IServiceScopeFactory {
        IServiceScope createScope();
    }

    interface IServiceProviderEngineCallback {
        void onCreate(ServiceCallSite callSite);
        void onResolve(Type serviceType, IServiceScope scope);
    }

    interface IServiceRealizationFunc {
        Object invoke(ServiceProviderEngineScope scope);
    }

    // #endregion
    // ==================
}
