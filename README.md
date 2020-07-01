# Apex DI

![](https://img.shields.io/badge/version-1.2-brightgreen.svg) ![](https://img.shields.io/badge/build-passing-brightgreen.svg) ![](https://img.shields.io/badge/coverage-90%25-brightgreen.svg)

A DI system ported from .Net Core for Apex classes. The APIs and internal implementations are similar to its [.Net Core](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-3.1) counterpart. Except there is no scpoed lifetime in Apex, since all Apex singltons are scoped OOTB.

## Usage

### Service Registration

Only two lifetimes of the servcies are supported:

1. **Singleton**: only one instance will be instanciated for each service provider per transaction.
2. **Transient**: new instances will be created everytime when `getService()` is called.

```java
DI.IServiceProvider provider = new DI.ServiceCollection()
    // 1. register transient services
    .addTransient(CaseService.class)
    .addTransient(IContactService.class, ContactService.class)
    .addTransient(IAccountService.class, new AccountService.Factory())

    // 2. register singleton services
    .addSingleton(Configuration.class)
    .addSingleton(IRecordTypeMap.class, RecordTypeMap.class)

    // 3. register multiple implementations of the same interface
    .addSingleton(ILogService.class, EmailLogService.class)
    .addSingleton(ILogService.class, TableLogService.class)
    .addSingleton(ILogService.class, new AWSS3LogService.Factory())

     // 4. build the servcie provider
    .BuildServiceProvider();
```

### Service Resolution

Services can be resovled as either a single object or a list of objects.

```java
public void resolve(DI.IServiceProvider provider) {
    // 5. APIs to resolve singleton or transient services are the same
    Configuration configuration = (Configuration)provider.getService(Configuration.class);
    IRecordTypeMap recordTypeMap = (IRecordTypeMap)provider.getService(IRecordTypeMap.class);

    // 6.1. resolve all services implementing the same interface
    List<ILogService> logServices = (List<ILogService>)provider.getServices(List<ILogService>.class);

    // 6.2. the last one is returned if only one instance is resolved
    ILogService logService = (ILogService)provider.getService(ILogService.class);
    System.assertEquals(logServices[2], logService);
}
```

### Provider Wrapper

A wrapper is necessary, so during unit test the `SalesModule.provider` static variable can be replaced with a mockup service provider.

```java
public class SalesModule implements DI.IServiceProvider {
    public static Object getService(Type serviceType) {
        return provider.getService(serviceType);
    }

    public static List<Object> getServices(Type serviceType) {
        return provider.getServices(serviceType);
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
                (IContactService)provider.getService(IContactService.class)
                (CaseService)provider.getService(CaseService.class)
            );
        }
    }

    public AccountService(
        IDBContext dbcontext,
        DBRepository repository,
        GlobalConfiguration config,
        IContactService contactService,
        CaseService caseService
    ) { }
}
```

### Apex Database Context

It is much easier to use the [Apex Database Context](https://github.com/apexfarm/ApexDatabaseContext) library with this Apex DI library. Just register the `DBContext` and `DBRepository` as below:

```java
DI.IServiceProvider provider = new DI.ServiceCollection()
    .addTransient(IDBContext.class, DBContext.class)
    .addTransient(IDBRepository.class, DBRepository.class)
    .BuildServiceProvider();
```
And relace the `DBContext` with `DBContextMock` for unit tests.

```java
DI.IServiceProvider provider = new DI.ServiceCollection()
    .addTransient(IDBContext.class, DBContextMock.class)
    .addTransient(IDBRepository.class, DBRepository.class)
    .BuildServiceProvider();
```

## License

BSD 3-Clause License
