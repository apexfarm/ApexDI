/**
 * BSD 3-Clause License
 *
 * Copyright (c) 2020, https://github.com/apexfarm/ApexDI
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

public with sharing class DI {

    enum ServiceLifetime {
        TransientLifeTime,
        SingletonLifeTime,
        ScopedLifeTime
    }

    class ServiceDescriptor {
        ServiceLifetime lifetime { get; private set; }
        Type serviceType { get; private set; }
        Type implementationType { get; private set; }
        Object implementationInstance { get; private set; }
        IServiceFactory implementationFactory { get; private set; }

        ServiceDescriptor(Type serviceType, Type implementationType, ServiceLifetime lifetime) {
            this.serviceType = serviceType;
            this.implementationType = implementationType;
            this.lifetime = lifetime;
        }

        ServiceDescriptor(Type serviceType, Object implementationInstance, ServiceLifetime lifetime) {
            this.serviceType = serviceType;
            this.implementationInstance = implementationInstance;
            this.lifetime = lifetime;
        }

        ServiceDescriptor(Type serviceType, IServiceFactory implementationFactory, ServiceLifetime lifetime) {
            this.serviceType = serviceType;
            this.implementationFactory = implementationFactory;
            this.lifetime = lifetime;
        }
    }

    public class ServiceCollection implements IServiceCollection {

        final List<ServiceDescriptor> descriptors { get; set; }

        {
            descriptors = new List<ServiceDescriptor>();
        }

        public IServiceProvider buildServiceProvider() {
            return new ServiceProvider(descriptors);
        }

        public IServiceCollection addTransient(Type serviceType) {
            return add(serviceType, serviceType, ServiceLifetime.TransientLifeTime);
        }

        public IServiceCollection addTransient(Type serviceType, Type implementationType) {
            return add(serviceType, implementationType, ServiceLifetime.TransientLifeTime);
        }

        public IServiceCollection addTransient(Type serviceType, IServiceFactory factory) {
            return add(serviceType, factory, ServiceLifetime.TransientLifeTime);
        }

        public IServiceCollection addSingleton(Type serviceType) {
            return add(serviceType, serviceType, ServiceLifetime.SingletonLifeTime);
        }

        public IServiceCollection addSingleton(Type serviceType, Type implementationType) {
            return add(serviceType, implementationType, ServiceLifetime.SingletonLifeTime);
        }

        public IServiceCollection addSingleton(Type serviceType, IServiceFactory factory) {
            return add(serviceType, factory, ServiceLifetime.SingletonLifeTime);
        }

        IServiceCollection add(Type serviceType, IServiceFactory implementationFactory, ServiceLifetime lifetime) {
            descriptors.add(new ServiceDescriptor(serviceType, implementationFactory, lifetime));
            return this;
        }

        IServiceCollection add(Type serviceType, Type implementationType, ServiceLifetime lifetime) {
            descriptors.add(new ServiceDescriptor(serviceType, implementationType, lifetime));
            return this;
        }
    }

    /**
     * ========== Service Provider ==========
     */

    class ServiceProvider implements IServiceProvider, IServiceProviderEngineCallback  {

        IServiceProviderEngine engine { get; set; }

        ServiceProvider(List<ServiceDescriptor> serviceDescriptors) {
            IServiceProviderEngineCallback callback = this;
            engine = new RuntimeServiceProviderEngine(serviceDescriptors, callback);
        }

        public Object getService(Type serviceType) {
            return engine.getService(serviceType);
        }

        public List<Object> getServices(Type serviceType, List<Object> services) {
            return engine.getServices(serviceType, services);
        }

        public void onCreate(ServiceCallSite callSite) {

        }

        public void onResolve(Type serviceType, IServiceScope scope) {

        }
    }

    abstract class ServiceProviderEngine implements IServiceProviderEngine, IServiceScopeFactory {
        List<ServiceDescriptor> serviceDescriptors { get; set; }
        IServiceProviderEngineCallback callback { get; set; }
        CallSiteFactory callSiteFactory { get; set; }
        CallSiteRuntimeResolver callSiteResolver { get; set; }
        ServiceProviderEngineScope root { get; set; }
        IServiceScope rootScope { get { return root; } }
        protected Map<Type, IServiceRealizationCall> realizedServices { get; private set; }

        ServiceProviderEngine(List<ServiceDescriptor> serviceDescriptors, IServiceProviderEngineCallback callback) {
            this.serviceDescriptors = serviceDescriptors;
            this.callback = callback;
            this.callSiteFactory = new CallSiteFactory(this.serviceDescriptors);
            this.callSiteFactory.add(IServiceProvider.class, new ServiceProviderCallSite());
            this.callSiteResolver = new CallSiteRuntimeResolver();
            this.root = new ServiceProviderEngineScope(this);
            this.realizedServices = new Map<Type, IServiceRealizationCall>();
        }

        public IServiceScope createScope() {
            return new ServiceProviderEngineScope(this);
        }

        public Object getService(Type serviceType) {
            return this.getService(serviceType, this.root);
        }

        public List<Object> getServices(Type serviceType, List<Object> services) {
            if (services != null) {
                for (Object service : (List<Object>)this.getService(serviceType, this.root)) {
                    services.add(service);
                }
            }
            return services;
        }

        Object getService(Type serviceType, ServiceProviderEngineScope serviceProviderEngineScope) {
            IServiceRealizationCall realizedService;
            if (this.realizedServices.containsKey(serviceType)) {
                realizedService = this.realizedServices.get(serviceType);
            } else {
                realizedService = createServiceAccessor(serviceType);
                this.realizedServices.put(serviceType, realizedService);
            }
            this.callback.onResolve(serviceType, serviceProviderEngineScope);
            return realizedService.invoke(serviceProviderEngineScope);
        }

        IServiceRealizationCall createServiceAccessor(Type serviceType) {
            ServiceCallSite callSite = this.callSiteFactory.GetCallSite(serviceType);
            if (callSite != null) {
                callback.onCreate(callSite);
                return this.realizeService(callSite);
            }

            return new NullServiceRealizationCall();
        }

        protected abstract IServiceRealizationCall realizeService(ServiceCallSite callSite);
    }


    class RuntimeServiceProviderEngine extends ServiceProviderEngine {
        RuntimeServiceProviderEngine(List<ServiceDescriptor> serviceDescriptors, IServiceProviderEngineCallback callback) {
            super(serviceDescriptors, callback);
        }

        protected override IServiceRealizationCall realizeService(ServiceCallSite callSite) {
            return new RuntimeServiceRealizationCall(callSite);
        }
    }

    class NullServiceRealizationCall implements IServiceRealizationCall {
        public Object invoke(ServiceProviderEngineScope scope) {
            return null;
        }
    }

    class RuntimeServiceRealizationCall implements IServiceRealizationCall {
        ServiceCallSite callSite { get; set; }

        RuntimeServiceRealizationCall(ServiceCallSite callSite) {
            this.callSite = callSite;
        }

        public Object invoke(ServiceProviderEngineScope scope) {
            return scope.engine.callSiteResolver.resolve(callSite, scope);
        }
    }

    class ServiceProviderEngineScope implements IServiceScope, IServiceProvider {
        ServiceProviderEngine engine { get; set; }
        Map<String, Object> resolvedServices { get; set; }

        ServiceProviderEngineScope(ServiceProviderEngine engine) {
            this.engine = engine;
            this.resolvedServices = new Map<String, Object>();
        }

        public IServiceProvider getServiceProvider() {
            return this;
        }

        public Object getService(Type serviceType) {
            return this.engine.getService(serviceType, this);
        }

        public List<Object> getServices(Type serviceType, List<Object> services) {
            for (Object service : (List<Object>)this.getService(serviceType)) {
                services.add(service);
            }
            return services;
        }
    }

    /**
     * ========== Call Site ==========
     */
    class CallSiteRuntimeResolver extends CallSiteVisitor {
        Object resolve(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            return visitCallSite(callSite, scope);
        }

        protected override Object visitRootCache(ServiceCallSite callSite, ServiceProviderEngineScope scope) {
            Map<String, Object> resolvedServices = scope.resolvedServices;
            if (!resolvedServices.containsKey(callSite.cache.key)) {
                resolvedServices.put(callSite.cache.key, visitCallSiteMain(callSite, scope));
            }
            return resolvedServices.get(callSite.cache.key);
        }
    }

    abstract class CallSiteVisitor {

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
                when Constructor {
                    return ((ConstructorCallSite)callSite).implementationType.newInstance();
                }
                when Factory {
                    return ((FactoryCallSite)callSite).factory.newInstance(scope);
                }
                when IEnumerable {
                    List<Object> services = new List<Object>();
                    for (ServiceCallSite serviceCallSite : ((IEnumerableCallSite)callSite).serviceCallSites) {
                        services.add(this.visitCallSite(serviceCallSite, scope));
                    }
                    return services;
                }
                when Constant {
                    return ((ConstantCallSite)callSite).defaultValue;
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

    class CallSiteFactory {
        final Integer DefaultSlot = 0;
        List<ServiceDescriptor> serviceDescriptors { get; set; }
        Map<Type, ServiceCallSite> callSiteCache { get; set; }

        CallSiteFactory(List<ServiceDescriptor> serviceDescriptors) {
            this.serviceDescriptors = serviceDescriptors;
            callSiteCache = new Map<Type, ServiceCallSite>();
        }

        void add(Type serviceType, ServiceCallSite callSite) {
            this.callSiteCache.put(serviceType, callSite);
        }

        ServiceCallSite getCallSite(Type serviceType){
            if (!callSiteCache.containsKey(serviceType)) {
                callSiteCache.put(serviceType, createCallSite(serviceType));
            }
            return callSiteCache.get(serviceType);
        }

        ServiceCallSite createCallSite(Type serviceType) {
            if (serviceType.getName().startsWith('List')) {
                return tryCreateEnumerable(serviceType);
            } else {
                return tryCreateExact(serviceType);
            }
        }

        ServiceCallSite tryCreateExact(Type serviceType) {
            ServiceCallSite callSite;
            for (Integer i = this.serviceDescriptors.size(); i > 0; i--) {
                callSite = tryCreateExact(serviceDescriptors[i - 1], serviceType);
                if (callSite != null) {
                    break;
                }
            }
            return callSite;
        }

        ServiceCallSite tryCreateExact(ServiceDescriptor descriptor, Type serviceType) {
            if (descriptor.serviceType == serviceType) {
                ServiceCallSite callSite;
                ResultCache lifetime = new ResultCache(descriptor.Lifetime, serviceType, descriptor.implementationType, this.DefaultSlot);
                if (descriptor.implementationInstance != null) {
                    callSite = new ConstantCallSite(serviceType, descriptor.implementationInstance);
                } else if (descriptor.implementationType != null) {
                    callSite = new ConstructorCallSite(lifetime, serviceType, descriptor.implementationType);
                } else if (descriptor.implementationFactory != null) {
                    callSite = new FactoryCallSite(lifetime, serviceType, descriptor.implementationFactory);
                } else {
                    throw new NoSuchElementException();
                }

                return callSite;
            }
            return null;
        }

        ServiceCallSite tryCreateEnumerable(Type serviceType) {
            Type itemType = getItemType(serviceType);
            List<ServiceCallSite> serviceCallSites = new List<ServiceCallSite>();
            for(ServiceDescriptor serviceDescriptor : this.serviceDescriptors) {
                ServiceCallSite callSite = tryCreateExact(serviceDescriptor, itemType);
                if (callSite != null) {
                    serviceCallSites.add(callSite);
                }
            }
            return new IEnumerableCallSite(itemType, serviceCallSites);
        }

        Type getItemType(Type serviceType) {
            String itemTypeName = serviceType.getName().replace('List<', '').replace('>', '');
            Type itemType;
            if (itemTypeName.indexOf('__') > 0) {
                List<String> splits = itemTypeName.split('__');
                itemType = Type.forName(splits[0], splits[1]);
            } else {
                itemType = Type.forName(itemTypeName);
            }
            return itemType;
        }
    }

    enum CallSiteKind {
        Factory,
        Constant,
        Constructor,
        IEnumerable,
        ServiceProvider,
        Transient,
        Singleton,
        Scoped
    }

    enum CallSiteResultCacheLocation {
        Root,
        Scope,
        Dispose,
        None
    }

    static final ResultCache RESULT_CACHE_NONE = new ResultCache(null, null, null, null);

    class ResultCache {
        CallSiteResultCacheLocation location { get; set; }
        String key { get; set; }

        ResultCache(ServiceLifetime lifetime, Type type, Type implementationType, Integer slot) {
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

            if (type != null && implementationType != null && slot != null) {
                this.key = type.getName() + implementationType.getName() + String.valueOf(slot);
            } else if (type != null && slot != null) {
                this.key = type.getName() + String.valueOf(slot);
            }
        }
    }

    abstract class ServiceCallSite {
        protected Type serviceType { get; set; }
        protected Type implementationType { get; set; }
        protected CallSiteKind kind { get; set; }
        protected ResultCache cache { get; set; }

        ServiceCallSite(ResultCache cache) {
            this.cache = cache;
        }
    }

    class ConstructorCallSite extends ServiceCallSite {
        ConstructorCallSite(ResultCache cache, Type serviceType, Type implementationType) {
            super(cache);
            this.serviceType = serviceType;
            this.implementationType = implementationType;
            this.kind = CallSiteKind.Constructor;
        }

    }

    class FactoryCallSite extends ServiceCallSite {
        IServiceFactory factory { get; set; }

        FactoryCallSite(ResultCache cache, Type serviceType, IServiceFactory factory) {
            super(cache);
            this.serviceType = serviceType;
            this.factory = factory;
            this.kind = CallSiteKind.Factory;
        }
    }

    class ConstantCallSite extends ServiceCallSite {
        Object defaultValue { get; set; }

        ConstantCallSite(Type serviceType, Object defaultValue) {
            super(RESULT_CACHE_NONE);
            this.serviceType = serviceType;
            this.defaultValue = defaultValue;
            this.kind = CallSiteKind.Constant;
        }
    }

    class ServiceProviderCallSite extends ServiceCallSite {
        ServiceProviderCallSite() {
            super(RESULT_CACHE_NONE);
            this.serviceType = IServiceProvider.class;
            this.implementationType = ServiceProvider.class;
            this.kind = CallSiteKind.ServiceProvider;
        }
    }

    class IEnumerableCallSite extends ServiceCallSite {
        Type itemType { get; set; }
        List<ServiceCallSite> serviceCallSites { get; set; }

        IEnumerableCallSite(Type itemType, List<ServiceCallSite> serviceCallSites) {
            super(RESULT_CACHE_NONE);
            this.itemType = itemType;
            this.serviceCallSites = serviceCallSites;
            this.kind = CallSiteKind.IEnumerable;
        }
    }

    /**
     * ========== Interfaces ==========
     */

    public interface IServiceCollection {
        IServiceProvider buildServiceProvider();
        IServiceCollection addTransient(Type serviceType);
        IServiceCollection addTransient(Type serviceType, Type implementationType);
        IServiceCollection addTransient(Type serviceType, IServiceFactory factory);
        IServiceCollection addSingleton(Type serviceType);
        IServiceCollection addSingleton(Type serviceType, Type implementationType);
        IServiceCollection addSingleton(Type serviceType, IServiceFactory factory);
    }

    public interface IServiceProvider {
        Object getService(Type serviceType);
        List<Object> getServices(Type serviceType, List<Object> services);
    }

    interface IServiceProviderEngine extends IServiceProvider {

    }

    interface IServiceScope {
        IServiceProvider getServiceProvider();
    }

    interface IServiceScopeFactory {
        IServiceScope createScope();
    }

    interface IServiceProviderEngineCallback {
        void onCreate(ServiceCallSite callSite);
        void onResolve(Type serviceType, IServiceScope scope);
    }

    interface IServiceRealizationCall {
        Object invoke(ServiceProviderEngineScope scope);
    }

    public interface IServiceFactory {
        Object newInstance(IServiceProvider serviceProvider);
    }
}
