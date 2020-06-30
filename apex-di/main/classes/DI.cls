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
        SingletonLifeTime
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

        public List<Object> getService(Type serviceType, List<Object> services) {
            return engine.getService(serviceType, services);
        }

        public void onCreate(ServiceCallSite callSite) {

        }

        public void onResolve(Type serviceType) {

        }
    }

    abstract class ServiceProviderEngine implements IServiceProviderEngine {
        List<ServiceDescriptor> serviceDescriptors { get; set; }
        IServiceProviderEngineCallback callback { get; set; }
        CallSiteFactory callSiteFactory { get; set; }
        CallSiteVisitor callSiteVisitor { get; set; }
        protected Map<Type, IServiceRealizationCall> realizedServices { get; private set; }

        ServiceProviderEngine(List<ServiceDescriptor> serviceDescriptors, IServiceProviderEngineCallback callback) {
            this.serviceDescriptors = serviceDescriptors;
            this.callback = callback;
            this.callSiteFactory = new CallSiteFactory(this.serviceDescriptors);
            this.callSiteFactory.add(IServiceProvider.class, new ServiceProviderCallSite());
            this.callSiteVisitor = new CallSiteVisitor();
            this.realizedServices = new Map<Type, IServiceRealizationCall>();
        }

        public Object getService(Type serviceType) {
            IServiceRealizationCall realizedService;
            if (realizedServices.containsKey(serviceType)) {
                realizedService = realizedServices.get(serviceType);
            } else {
                realizedService = createServiceAccessor(serviceType);
                realizedServices.put(serviceType, realizedService);
            }
            callback.OnResolve(serviceType);
            return realizedService.invoke(this);
        }

        public List<Object> getService(Type serviceType, List<Object> services) {
            for (Object service : (List<Object>)getService(serviceType)) {
                services.add(service);
            }
            return services;
        }

        IServiceRealizationCall createServiceAccessor(Type serviceType) {
            ServiceCallSite callSite = this.callSiteFactory.GetCallSite(serviceType);
            if (callSite != null) {
                callback.OnCreate(callSite);
                return realizeService(callSite);
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
        public Object invoke(ServiceProviderEngine engine) {
            return null;
        }
    }

    class RuntimeServiceRealizationCall implements IServiceRealizationCall {
        ServiceCallSite callSite { get; set; }

        RuntimeServiceRealizationCall(ServiceCallSite callSite) {
            this.callSite = callSite;
        }

        public Object invoke(ServiceProviderEngine engine) {
            return engine.callSiteVisitor.visitCallSite(callSite, engine);
        }
    }

    /**
     * ========== Call Site ==========
     */

    class CallSiteVisitor {
        Object visitCallSite(ServiceCallSite callSite, IServiceProvider serviceProvider) {
            switch on callSite.kind {
                when Constructor {
                    return ((ConstructorCallSite)callSite).implementationType.newInstance();
                }
                when Factory {
                    return ((FactoryCallSite)callSite).factory.newInstance(serviceProvider);
                }
                when IEnumerable {
                    List<Object> services = new List<Object>();
                    for (ServiceCallSite serviceCallSite : ((IEnumerableCallSite)callSite).serviceCallSites) {
                        services.add(this.visitCallSite(serviceCallSite, serviceProvider));
                    }
                    return services;
                }
                when Constant {
                    return ((ConstantCallSite)callSite).defaultValue;
                }
                when ServiceProvider {
                    return serviceProvider;
                }
                when else {
                    throw new NoSuchElementException();
                }
            }
        }
    }

    class CallSiteFactory {
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

        ServiceCallSite tryCreateExact(ServiceDescriptor serviceDescriptor, Type serviceType) {
            if (serviceDescriptor.serviceType == serviceType) {
                ServiceCallSite callSite;
                if (serviceDescriptor.implementationType != null) {
                    callSite = new ConstructorCallSite(serviceType, serviceDescriptor.implementationType);
                } else if (serviceDescriptor.implementationInstance != null) {
                    callSite = new ConstantCallSite(serviceType, serviceDescriptor.implementationInstance);
                } else if (serviceDescriptor.implementationFactory != null) {
                    callSite = new FactoryCallSite(serviceType, serviceDescriptor.implementationFactory);
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
        Singleton
    }

    virtual class ServiceCallSite {
        protected Type serviceType { get; set; }
        protected Type implementationType { get; set; }
        protected CallSiteKind kind { get; set; }
    }

    class ServiceProviderCallSite extends ServiceCallSite {
        ServiceProviderCallSite() {
            this.serviceType = IServiceProvider.class;
            this.implementationType = ServiceProvider.class;
            this.kind = CallSiteKind.ServiceProvider;
        }
    }

    class ConstructorCallSite extends ServiceCallSite {
        ConstructorCallSite(Type serviceType, Type implementationType) {
            this.serviceType = serviceType;
            this.implementationType = implementationType;
            this.kind = CallSiteKind.Constructor;
        }

    }

    class ConstantCallSite extends ServiceCallSite {
        Object defaultValue { get; set; }

        ConstantCallSite(Type serviceType, Object defaultValue) {
            this.serviceType = serviceType;
            this.defaultValue = defaultValue;
            this.kind = CallSiteKind.Constant;
        }
    }

    class FactoryCallSite extends ServiceCallSite {
        IServiceFactory factory { get; set; }

        FactoryCallSite(Type serviceType, IServiceFactory factory) {
            this.serviceType = serviceType;
            this.factory = factory;
            this.kind = CallSiteKind.Factory;
        }
    }

    class IEnumerableCallSite extends ServiceCallSite {
        Type itemType { get; set; }
        List<ServiceCallSite> serviceCallSites { get; set; }

        IEnumerableCallSite(Type itemType, List<ServiceCallSite> serviceCallSites) {
            super();
            this.itemType = itemType;
            this.serviceCallSites = serviceCallSites;
            this.kind = CallSiteKind.IEnumerable;
        }
    }

    /**
     * ========== Interfaces ==========
     */

    public interface IServiceFactory {
        Object newInstance(IServiceProvider serviceProvider);
    }

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
        List<Object> getService(Type serviceType, List<Object> services);
    }

    interface IServiceProviderEngine extends IServiceProvider {

    }

    interface IServiceProviderEngineCallback {
        void onCreate(ServiceCallSite callSite);
        void onResolve(Type serviceType);
    }

    interface IServiceRealizationCall {
        Object invoke(ServiceProviderEngine engine);
    }
}
