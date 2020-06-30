# Apex DI

![](https://img.shields.io/badge/version-1.0-brightgreen.svg) ![](https://img.shields.io/badge/build-passing-brightgreen.svg) ![](https://img.shields.io/badge/coverage-90%25-brightgreen.svg)

A DI system ported from .Net Core for Apex classes.

## Usage

### Define Service Collection

```java
public class Application implements DI.IServiceProvider {
  	public static Object getService(Type serviceType) {
        return provider.getService(serviceType);
    }
  
    public static List<Object> getServices(Type serviceType, List<Object> services) {
        return provider.getService(serviceType, services);
    }

    public static DI.IServiceProvider provider {
        get {
            if (provider == null) {
                provider = new DI.ServiceCollection()
                    .addSingleton(GlobalConfiguration.class)
                    .addSingleton(ILogService.class, TableLogService.class)
                    .addSingleton(ILogService.class, EmailLogService.class)
                    .addSingleton(ILogService.class, new AWSS3LogServiceFactory())
                    .addTransient(IDBContext.class, DBContext.class)
                    .addTransient(IDBRepository.class, DBRepository.class)
                    .addTransient(DBRepository.class)
                    .addTransient(IAccountService.class, new AccountServiceFactory())
                    .BuildServiceProvider();
            }
            return provider;
        }
        set;
    }
}
```

### Inject Services with Factory

```java
public class AccountServiceFactory implements DI.IServiceFactory {
    public IAccountService newInstance(DI.IServiceProvider provider) {
        return new AccountService(
            // return a list of all services implementing ILogService
            (List<ILogService>)provider.getService(List<ILogService>.class, new List<ILogService>()),
            (IDBContext)provider.getService(IDBContext.class),
            (IDBRepository)provider.getService(IDBRepository.class),
            (IDBRepository)provider.getService(IDBRepository.class),
            (GlobalConfiguration)provider.getService(GlobalConfiguration.class)
        );
    }
}
```

