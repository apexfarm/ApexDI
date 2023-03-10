# Apex DI

![](https://img.shields.io/badge/version-2.0-brightgreen.svg) ![](https://img.shields.io/badge/build-passing-brightgreen.svg) ![](https://img.shields.io/badge/coverage-%3E90%25-brightgreen.svg)

A lightweight Apex dependency injection ([wiki](https://en.wikipedia.org/wiki/Dependency_injection)) framework that can help:

1. Adopt some of the best practices of dependency injection pattern:
   - Decouple implementations and code against abstractions.
   - Highly reusable, extensible and testable code.
2. Structure project development in a modular structure:
   - Create boundaries to avoid loading of unused services into current module.
   - Create dependencies to increase the reusability of services in other modules.

| Environment           | Installation Link                                                                                                                                         | Version |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| Production, Developer | <a target="_blank" href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04t2v000007CfeFAAS"><img src="docs/images/deploy-button.png"></a> | ver 2.0 |
| Sandbox               | <a target="_blank" href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04t2v000007CfeFAAS"><img src="docs/images/deploy-button.png"></a>  | ver 2.0 |

Here is an example controller, when `DI.Module` is used to resolve services. As you can see, the controller doesn't depend on concrete types, it becomes thin and clean!

```java
public with sharing class AccountController {
    private static final IAccountService accountService;
    private static final ILogger logger;

    static {
        DI.Module module = DI.getModule(SalesModule.class);
        accountService = (IAccountService) module.getService(IAccountService.class);
        logger = (ILogger) module.getService(ILogger.class);
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts(Integer top) {
        try {
            return accountService.getAccounts(top);
        } catch (Exception ex) {
            logger.log(ex);
            throw new AuraHandledException(ex.getMessage());
        }
    }
}
```

---

## Table of Contents

- [1. Services](#1-services)
  - [1.1 Service Lifetime](#11-service-lifetime)
  - [1.2 Register with Concrete Types](#12-register-with-concrete-types)
  - [1.3 Register with Multiple Implementations](#13-register-with-multiple-implementations)
  - [1.4 Register with Factory](#14-register-with-factory)
- [2. Modules](#2-modules)
  - [2.1 Module Creation](#21-module-creation)
  - [2.2 Module Dependencies](#22-module-dependencies)
  - [2.3 Module File Structure](#23-module-file-structure)
- [3. Tests](#3-tests)
  - [3.1 Test with Mockup Replacement](#31-test-with-mockup-replacement)
  - [3.2 Test with a Mockup Library](#32-test-with-a-mockup-library)
  - [3.3 Test with Service Provider](#33-test-with-service-provider)
- [4. API Reference](#4-api-reference)
  - [4.1 DI Class](#41-di-class)
  - [4.2 DI.ServiceCollection Interface](#42-diservicecollection-interface)
  - [4.3 DI.ServiceProvider Interface](#43-diserviceprovider-interface)
  - [4.4 DI.ServiceFactory Interface](#44-diservicefactory-interface)
  - [4.5 DI.Module Abstract Class](#45-dimodule-abstract-class)
- [5. License](#5-license)

## 1. Services

Here is a simple example about how to register the service class into a DI container, and consume it. We use the type name strings during service registration, but use strong types during service resolution phase. This is because in apex, each time a transaction reaches a class declaration on the first time, all its static properties are going to be initialized and loaded at that time. If an Apex DI framework registered with hundreds of classes/interfaces with strong types, it will initialize all their static properties, which will harm the performance badly.

```java
public interface IAccountService {}
public with sharing class AccountService implements IAccountService {}

DI.ServiceProvider provider = DI.services()            // 1. create a DI.ServiceCollection
    .addTransient('IAccountService', 'AccountService') // 2. register a service interface with its implementation class
    .BuildServiceProvider();                           // 3. build a DI.ServiceProvider

IAccountService accountService = (IAccountService) provider.getService(IAccountService.class);
```

### 1.1 Service Lifetime

Every service has a lifetime, the library supports two different lifetimes:

1. **Transient**: new instances will be created whenever `getService()` is invoked.
2. **Singleton**: the same instance will be returned whenever `getService()` is invoked.

```java
DI.ServiceProvider provider = DI.services()
    .addTransient('IAccountService', 'AccountService') // 1. register transient services
    .addSingleton('ILogger', 'AWSS3Logger')            // 2. register singleton services
    .BuildServiceProvider();

// transient lifetime: different services are returned
Assert.areNotEqual(provider.getService(IAccountService.class), provider.getService(IAccountService.class));
// singleton lifetime: the same service is returned
Assert.areEqual(provider.getService(IUtility.class), provider.getService(IUtility.class));
```

### 1.2 Register with Concrete Types

It is generally **NOT** recommended, but services can also be registered against their own types without abstractions. This will no longer enable us to code against abstractions, which is one of the main reason we choose a DI framework. However, sometimes it is still **OK** for classes to be registered in this way, such as a `Utility` class.

```java
DI.ServiceProvider provider = DI.services()
    .addTransient('AccountService')
    .addTransient('AccountService', 'AccountService') // equivalent to above
    .addSingleton('Utility')
    .addSingleton('Utility', 'Utility')               // equivalent to above
    .BuildServiceProvider();

AccountService accountService = (AccountService) provider.getService(AccountService.class);
```

### 1.3 Register with Multiple Implementations

Multiple different service implementations of the same abstraction can be registered in the same DI container. With `ServiceProvider.getServices(Type serviceType)`, all implementations can be resolved together. **Note**: the API name `getServices` ends with plural services.

```java
public interface ILogger { void error(); void warn(); }
public class EmailLogger implements ILogger {} // email errors to developers or adminstrators
public class TableLogger implements ILogger {} // save errors to a backend database

DI.ServiceProvider provider = DI.services()
    .addSingleton('ILogger', 'EmailLogger')
    .addSingleton('ILogger', 'TableLogger')
    .addSingleton('ILogger', 'AWSS3Logger')
    .BuildServiceProvider();

// services are returned in the reverse order as they registered
List<ILogger> loggers = (List<ILogger>) provider.getServices(ILogger.class);
```

The singular form API `getServcie` can still be used, it will return the last service registered. This also gives advantage when override services implemented in the dependent modules. For example, in test class, we can register a mockup service at the last, so the mockup service will be returned in your test methods.

```java
ILogger logger = (ILogger) provider.getService(ILogger.class)
Assert.isTrue(logger instanceof AWSS3Logger);
```

### 1.4 Register with Factory

The framework is chosen to use constructor injection. However it is impossible to implement a dynamic injector with current Apex API, so the library uses a factory ([wiki](<https://en.wikipedia.org/wiki/Factory_(object-oriented_programming)>)) + service locator pattern ([wiki](https://en.wikipedia.org/wiki/Service_locator_pattern)) to inject dependencies to a constructor. The **drawback** is that the factory introduces a little additional codes to be maintained manually, but your service class is going to be cleaner. **P.S.** with VS Code language server protocol we can create a VS Code extension to generate the factory classes automatically in future, but it is not our focus for now.

```java
// 1. Service Factory
public class AccountServiceFactory implements DI.ServiceFactory {
    public IAccountService newInstance(DI.ServiceProvider provider) {
        return new AccountService(
            (ILogger) provider.getService(ILogger.class)
        );
    }
}

// 2. Service Registrition
DI.ServiceProvider provider = DI.services()
    .addTransientFactory('IAccountService', 'AccountServiceFactory')
    .addSingleton('ILogger', 'AWSS3Logger')
    .BuildServiceProvider();

IAccountService accountService = (IAccountService) provider.getService(IAccountService.class);
```

And here are the definitions of `IAccountService` and `AccountService` to support the above example. `AccountService` also doesn't depend on any concrete implementations of other services, which make it thinner and cleaner!

```java
public interface IAccountService {}

public with sharing class AccountService implements IAccountService {
    private ILogger logger { get; set; }

    public AccountService(ILogger logger) {
        this.logger = logger;
    }
}
```

We can also define the factory as an inner class of the service, so we don't need to create a standalone factory class file, in case the `classes` folder become huge.

```java
public with sharing class AccountService implements IAccountService {
    private ILogger logger { get; set; }
    public AccountService(ILogger logger) { this.logger = logger; }

    public class Factory implements DI.ServiceFactory {              // factory declared as inner class
        public IAccountService newInstance(DI.ServiceProvider provider) {
            return new AccountService(
                (ILogger) provider.getService(ILogger.class)
            );
        }
    }
}

DI.ServiceProvider provider = DI.services()
    .addTransientFactory('IAccountService', 'AccountService.Factory') // factory registered as inner class
    .addSingleton('ILogger', 'AWSS3Logger')
    .BuildServiceProvider();
```

## 2. Modules

It is highly recommended to use a `DI.Module` to manage service registrations, so it can help:

- Create boundaries to reduce loading of unused services into current module.
- Create dependencies to increase the reusability of services in other modules.

### 2.1 Module Creation

A module is defined with a class inherited from `DI.Module`. Override method `void build(DI.IServiceCollection services)` to register services into it. It can be resolved later with `DI.getModule(Type moduleType)` API. Module will be resolved as singleton, so every time the same instance is returned by `getModule` for the same module class.

```java
public class LogModule extends DI.Module {
    public override void build(DI.IServiceCollection services) {
        services.addSingleton('ILogger', 'AWSS3Logger');
    }
}

// use module to resolve services
DI.Module logModule = DI.getModule(LogModule.class);
ILogger logger = (ILogger) logModule.getServcie(ILogger.class);
```

### 2.2 Module Dependencies

A module can also depends on the other modules to maximize module reusability. For example, the following `SalesModule` depends on the `LogModule` module defined above. So `ILogger` service can also be injected into services inside `SalesModule`.

```java
public class SalesModule extends DI.Module {
    public override void imports(List<String> modules) { // declare module dependencies
        modules.add('LogModule');
    }

    public override void build(DI.IServiceCollection services) {
        services
            .addSingleton('IAccountRepository', 'AccountRepository')
            .addTransientFactory('IAccountService', 'AccountService');
    }
}
```

### 2.3 Module File Structure

When project become huge, we can divide modules into different folders, so it gives us focus to the modules developing at hands. Please check the sfdx document [Multiple Package Directories](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_mpd.htm) regarding how to do it.

```
|-- sales-module/main/default/
  |-- classes/
    |-- AccountRepository.cls
    |-- AccountService.cls
    |-- IAccountRepository.cls
    |-- IAccountService.cls
    |-- SalesModule.cls
|-- log-module/main/default/
  |-- classes/
    |-- AWSS3Logger.cls
    |-- ILogger.cls
    |-- LogModule.cls
```

## 3. Tests

### 3.1 Test with Mockup Replacement

There is a controller defined at the top of the page. We use it as an example to create the test class `AccountControllerTest`, because controller is special (i.e. controller is running in static context, while our DI is in instance context). We try to replace the module returned by `DI.getModule(SalesModule.cass)` with a mock module at runtime, so mock up services can be injected into the controller.

1. Use `DI.setModule` API to replace `SalesModule` with the `MockSalesModule` defined as inner class. **Note**: `DI.setModule` must be called before the first reference of the `AccountController` class.
1. Extend `SalesModule` with `MockSalesModule`. **Note**: both the `SalesModule` class and its `build` method need to be declared as `virtual` prior.
1. Use `services.addTransient` to override `IAccountService` with the `MockAccountService` inner class.

```java
@isTest
public class AccountControllerTest {
    @isTest
    static void testGetAccounts() {
        DI.setModule(SalesModule.class, MockSalesModule.class);        // #1
        List<Account> accounts = AccountController.getAccounts(3);
        Assert.areEqual(3, accounts.size());
    }

    public class MockSalesModule extends SalesModule {                 // #2
        protected override void build(DI.ServiceCollection services) { // #3
            super.build(services);
            services.addTransient('IAccountService', 'AccountControllerTest.MockAccountService');
        }
    }

    public class MockAccountService implements IAccountService {       // the mockup service
        public List<Account> getAccounts(Integer top) {
            return new List<Account>{ new Account(), new Account(), new Account() };
        }
    }
}
```

### 3.2 Test with a Mockup Library

We can also directly create a mockup service instance and register it against `IAccountService` with `addTransient` API. The following example uses ApexTestKit ([github](https://github.com/apexfarm/ApexTestKit)) as its mocking library.

```java
@isTest
public class AccountControllerTest {
    @isTest
    static void testGetAccounts() {
        DI.setModule(SalesModule.class, MockSalesModule.class);
        List<Account> accounts = AccountController.getAccounts(3);
        Assert.areEqual(3, accounts.size());
    }

    public class MockSalesModule extends DI.Module {
        public override void imports(List<String> modules) {
            modules.add('SalesModule');
        }

        public override void build(DI.IServiceCollection services) {
            AccountService mockAccountService = (AccountService) ATK.mock(AccountService.class); // the mockup service
            ATK.startStubbing();
            ATK.given(accountServiceMock.getAccounts(3)).willReturn(
                ATK.prepare(Account.SObjectType, 3)
                	.field(Account.Name).index('Name-{0000}')
                	.mock().get(Account.SObjectType)
            });
            ATK.stopStubbing();

            services.addTransient('IAccountService', mockAccountService);                       // register an instance directly
        }
    }
}
```

### 3.3 Test with Service Provider

This is not suitable to test static classes as controllers, but will be a convenient way to test services registered in a DI. The following `AccountService` may depend on `IAccountRepository` to perform the CRUD requests to Salesforce database. We can also replace `IAccountRepository` by creating a mockup repository, so no actual requests are made to Salesforce database, which gives performance improvement a lot.

```java
@isTest
public class AccountServiceTest {
    @isTest
    static void testGetAccounts() {
        DI.ServiceProvider provider = DI.services()
            .addTransientFactory('IAccountService', 'AccountService.Factory')
            .addSingleton('IAccountRepository', 'AccountRepository')
            .BuildServiceProvider();

        IAccountService accountService = (IAccountService.class) provider.getService(IAccountService.class);
        List<Account> accounts = accountService.getAccounts(3);
        Assert.areEqual(3, accounts.size());
    }
}

public with sharing AccountServcie {
    private IAccountRepository accountRepository { get; set; }

    public AccountServcie(IAccountRepository accountRepository) {
        this.accountRepository = accountRepository;
    }

    public class Factory implements DI.ServiceFactory {
        public IAccountService newInstance(DI.ServiceProvider provider) {
            return new AccountService(
                (IAccountRepository) provider.getService(IAccountRepository.class)
            );
        }
    }
}
```

## 4. API Reference

### 4.1 DI Class

| Static Methods                                                | Description                                                                                                                                             |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DI.ServiceCollection DI.services()`                          | Create an instance of `DI.ServiceCollection`.                                                                                                           |
| `DI.Module DI.getModule(Type moduleType)`                     | Create a singleton module with services registered. Use the `DI.ServiceProvider` interface to resolve them.                                             |
| `void DI.setModule(Type replacedModuleType, Type moduleType)` | Set a new `moduleType` to replace the `replacedModuleType` which is referenced somewhere. Mainly used in test classes, for runtime service replacement. |

### 4.2 DI.ServiceCollection Interface

Use this interface to register services into the container.

| Methods                                                                                    | Description                                                                                             |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `DI.ServiceCollection addTransient(String serviceTypeName)`                                | Register a transient type against its own type.                                                         |
| `DI.ServiceCollection addTransient(String serviceTypeName, Object instance)`               | Register a transient type against an instance of its own type or descendent types, i.e. a mock service. |
| `DI.ServiceCollection addTransient(String serviceTypeName, String implementationTypeName)` | Register a transient type against its descendent types.                                                 |
| `DI.ServiceCollection addTransientFactory(String serviceTypeName, String factoryTypeName)` | Register a transient type against its factory type.                                                     |
| `DI.ServiceCollection addSingleton(String serviceTypeName)`                                | Register a singleton type against its own type.                                                         |
| `DI.ServiceCollection addSingleton(String serviceTypeName, Object instance)`               | Register a singleton type against an instance of its own type or descendent types, i.e. a mock service. |
| `DI.ServiceCollection addSingleton(String serviceTypeName, String implementationTypeName)` | Register a singleton type against its descendent types.                                                 |
| `DI.ServiceCollection addSingletonFactory(String serviceTypeName, String factoryTypeName)` | Register a singleton type against its factory type.                                                     |
| `DI.ServiceProvider buildServiceProvider()`                                                | Create `DI.ServiceProvider` with services registered into the container.                                |

### 4.3 DI.ServiceProvider Interface

Use this interface to get the instances of the registered services.

| Methods                                        | Description                                            |
| ---------------------------------------------- | ------------------------------------------------------ |
| `Object getService(Type serviceType)`          | Get a single service of the supplied type.             |
| `Object getService(String serviceName)`        | Get a single service of the supplied type name string. |
| `List<Object> getServices(Type serviceType)`   | Get a all services of the supplied type.               |
| `List<Object> getServices(String serviceName)` | Get a all services of the supplied type name string.   |

### 4.4 DI.ServiceFactory Interface

Implement this interface to define a factory class to create a service with constructor injection.

| Methods                                                  | Description                                                                          |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `Object newInstance(DI.ServiceProvider serviceProvider)` | Use the `serviceProvider` to get the instances of the services defined in the scope. |

### 4.5 DI.Module Abstract Class

Implement this interface to define a module class. It is also an implementation of `DI.ServiceProvider` interface, so all `DI.ServiceProvider` methods can also be invoked.

| Methods                                                        | Description                                                                |
| -------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `protected virtual void import(List<String> modules)`          | Override this method to import other module services into this module.     |
| `protected abstract void build(DI.ServiceCollection services)` | [**Required**] Override this method to register services into this module. |

## 5. License

Apache 2.0
