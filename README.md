# Apex DI.Net

![](https://img.shields.io/badge/version-1.1-brightgreen.svg) ![](https://img.shields.io/badge/build-passing-brightgreen.svg) ![](https://img.shields.io/badge/coverage-85%25-brightgreen.svg)

A DI system ported from .Net Core for Apex classes. The APIs and internal implementations are almost identical to its [.Net Core Dependency Injection](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-3.1) counterpart. Except there is no scpoed lifetime in Apex, since Apex singltons are scoped OOTB.

## Usage

### Service Registration

Only two lifetimes of the servcies are supported:

1. **Singleton**: only one instance will be instanciated for each service provider.
2. **Transient**: new instance will be instanciated every time when `getService()` is called.

```java
DI.IServiceProvider provider = new DI.ServiceCollection()
    // 1. register singleton services
    .addSingleton(ServiceA.class)
    .addSingleton(IServiceB.class, ServiceB.class)
    .addSingleton(IServiceC.class, ServiceC1.class)
    .addSingleton(IServiceC.class, ServiceC2.class)
    .addSingleton(IServiceC.class, new ServiceC3.Factory())
    // 2. register transient services
    .addTransient(ServiceD.class)
    .addTransient(IServiceE.class, ServiceE.class)
    .addTransient(IAccountService.class, new AccountService.Factory())
     // 3. build the servcie provider
    .BuildServiceProvider();
```

### Service Resolution

Services can be resovled as a single object or a list of objects.

```java
// 4. APIs to resolve singleton or transient services are the same
ServiceA serviceA = (ServiceA)provider.getService(ServiceA.class);
IServiceB serviceB = (IServiceB)provider.getService(IServiceB.class);

// 5. resolve all services implement the same interface
List<IServiceC> serviceCList = (List<IServiceC>)provider.getServices(
    List<IServiceC>.class, new List<IServiceC>());

// 6. the last one is returned if multiple services registered for the same interface
IServiceC serviceC = (IServiceC)provider.getService(IServiceC.class);
System.assertEquals(serviceCList[2], serviceC);
```

### Provider Wrapper

A wrapper is necessary, so during unit test the `Application.provider` static variable can be replaced with a mockup service provider.

```java
public class Application implements DI.IServiceProvider {
  	public static Object getService(Type serviceType) {
        return provider.getService(serviceType);
    }

    public static List<Object> getServices(Type serviceType, List<Object> services) {
        return provider.getServices(serviceType, services);
    }

    public static DI.IServiceProvider provider {
        get {
            if (provider == null) {
                provider = new DI.ServiceCollection()
                    .addSingleton(GlobalConfiguration.class)
                    .addTransient(IAccountService.class, AccountService.class)
                    .BuildServiceProvider();
            }
            return provider;
        }
        set;
    }
}
```

### Service Factory

Service factory is used to help resolve service with constructor dependencies to other services.

```java
public class AccountService implements IAccountService {
    public class Factory implements DI.IServiceFactory {
        public IAccountService newInstance(DI.IServiceProvider provider) {
            return new AccountService(
                (IDBContext)provider.getService(IDBContext.class),
                (DBRepository)provider.getService(DBRepository.class),
                (GlobalConfiguration)provider.getService(GlobalConfiguration.class)
            );
        }
    }

    public AccountService(
        IDBContext dbcontext,
        DBRepository repository,
        GlobalConfiguration config
    ) { }
}
```

### Apex Database Context

It is much easier to use the [Apex Database Context](https://github.com/apexfarm/ApexDatabaseContext) library with this Apex DI. Just register the `DBContext` and `DBRepository` as below:

```java
DI.IServiceProvider provider = new DI.ServiceCollection()
    .addTransient(IDBContext.class, DBContext.class)
    .addTransient(DBRepository.class)
    .BuildServiceProvider();
```
And relace the `DBContext` with `DBContextMock` for unit tests.

```java
DI.IServiceProvider provider = new DI.ServiceCollection()
    .addTransient(IDBContext.class, DBContextMock.class)
    .addTransient(DBRepository.class)
    .BuildServiceProvider();
```

## License

BSD 3-Clause License