# Apex DI

![](https://img.shields.io/badge/version-3.0-brightgreen.svg) ![](https://img.shields.io/badge/build-passing-brightgreen.svg) ![](https://img.shields.io/badge/coverage-97%25-brightgreen.svg)

A lightweight Apex dependency injection framework ported from .Net Core. It can help:

1. Adopt some of the best practices of dependency injection pattern:
   - Decouple implementations and code against abstractions.
   - Highly reusable, extensible and testable code.
2. Manage project development in a modular structure:
   - Create boundaries to avoid loading of unused services into current module.
   - Create dependencies to increase the reusability of services in other modules.

| Environment           | Installation Link                                            | Version   |
| --------------------- | ------------------------------------------------------------ | --------- |
| Production, Developer | <a target="_blank" href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tGC000007TKk4YAG"><img src="docs/images/deploy-button.png"></a> | ver 3.0.0 |
| Sandbox               | <a target="_blank" href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04tGC000007TKk4YAG"><img src="docs/images/deploy-button.png"></a> | ver 3.0.0 |

---

### **v3.0 Release Notes**

- Upgraded to API version 63.0.
- Updated benchmark test results.
- Changed APIs:
  - `DI.types()` removed.
  - `DI.getModule` replaced with `DI.modules().get()`.
  - `DI.addModule` replaced with `DI.modules().replace()`.
  - `GenericServiceFactory.newInstance()` parameter order updated.


---

Here is an example controller, when `DI.Module` is used to resolve services. As you can see, the controller doesn't depend on any concrete types, it becomes thin and clean!

```java
public with sharing class AccountController {
    private static final IAccountService accountService;
    private static final ILogger logger;

    static {
        DI.Module module = DI.modules().get(SalesModule.class);
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

### Online Articles

- [Salesforce Dependency Injection with Apex DI](https://medium.com/@jeff.jianfeng.jin/salesforce-project-with-apex-dependency-injection-a3d0e369be25) (medium link)
- [Salesforce Generic Types with Apex DI](https://medium.com/@jeff.jianfeng.jin/salesforce-generic-types-with-apex-di-142a1d8132c3) (medium link)

---

## Table of Contents

- [1. Performance](#1-performance)
- [2. Services](#2-services)
  - [2.1 Service Lifetime](#21-service-lifetime)
  - [2.2 Register with Concrete Types](#22-register-with-concrete-types)
  - [2.3 Service Override](#23-service-override)
- [3. Factory](#3-factory)
  - [3.1 Factory Class](#31-factory-class)
  - [3.2 Factory Inner Class](#32-factory-inner-class)
  - [3.3 Generic Factory](#33-generic-factory)
- [4. Modules](#4-modules)
  - [4.1 Module Creation](#41-module-creation)
  - [4.2 Module Dependencies](#42-module-dependencies)
  - [4.3 Module File Structure](#43-module-file-structure)
- [5. Tests](#5-tests)
  - [5.1 Test with Service Mockup](#51-test-with-service-mockup)
  - [5.2 Test with Module Mockup](#52-test-with-module-mockup)
- [6. API Reference](#6-api-reference)
  - [6.1 DI Class](#61-di-class)
  - [6.2 DI.ServiceCollection Interface](#62-diservicecollection-interface)
  - [6.3 DI.ServiceProvider Interface](#63-diserviceprovider-interface)
  - [6.4 DI.ServiceFactory Interface](#64-diservicefactory-interface)
  - [6.5 DI.Module Abstract Class](#65-dimodule-abstract-class)
  - [6.6 DI.GlobalModuleCollection Interface](#66-diglobalmodulecollection-interface)
- [7. License](#7-license)

## 1. Performance

<p align="center"><img src="./docs/images/benchmark.png" width=800 alt="Performance Benchmark"></p>

1. Service registration with class names is currently the fastest solution, compared to strong class types. They almost cost nothing  (**green color line**).
2. Feel free to use interfaces and abstractions for service registration and resolution, this is the best practice. They have no impact to performance.
3. Feel free to use transient lifetime when appropriate. Once a service is realized, its "constructor" can be reused for the subsequent realization, which almost cost nothing (**blue color line**).
4. It is strongly recommended to use modules dividing services, and better to limit services below 100 per module.

## 2. Services

Here is a simple example about how to register the service class into a DI container.

```java
public interface IAccountService {}
public with sharing class AccountService implements IAccountService {}

DI.ServiceProvider provider = DI.services()            // 1. create a DI.ServiceCollection
    .addTransient('IAccountService', 'AccountService') // 2. register a service
    .BuildServiceProvider();                           // 3. build a DI.ServiceProvider

IAccountService accountService = (IAccountService) provider.getService(IAccountService.class);
```

### 2.1 Service Lifetime

The library defined three different widths and lengths of lifetimes:

1. **Singleton**: the same instance will be returned whenever `getService()` is invoked in organization-wide, even from different `DI.Module` or `DI.ServiceProvider`.
2. **Scoped**: the same instance will be returned only when `getService()` is invoked within the same `DI.Module` or `DI.ServiceProvider`. Can also be understood as a singleton within a module or provider, but not across them.
3. **Transient**: new instances will be created whenever `getService()` is invoked.

Lifetimes can also be interpreted as the following hierarchy, services registered in higher level (transient) have higher precedence over those registered in lower level (singleton) contexts.

<p align="center"><img src="./docs/images/lifetime-illustrated.png#2023-3-15" width=550 alt="Lifetime Hierarchy"></p>

The following code use `DI.ServiceProvider` to create service boundaries. [Modules](#4-modules) also follow the same mechanism.

```java
DI.ServiceProvider providerA = DI.services()
    .addSingleton('IUtility', 'Utility')               // 1. register singleton services
    .addScoped('ILogger', 'TableLogger')               // 2. register scoped services
    .addTransient('IAccountService', 'AccountService') // 3. register transient services
    .BuildServiceProvider();

DI.ServiceProvider providerB = DI.services()
    .addSingleton('IUtility', 'Utility')               // 1. register singleton services
    .addScoped('ILogger', 'TableLogger')               // 2. register scoped services
    .addTransient('IAccountService', 'AccountService') // 3. register transient services
    .BuildServiceProvider();

// 1. Singleton Lifetime:
Assert.areEqual(    // the same service is returned from providerA and providerB
    providerA.getService(IUtility.class),
    providerB.getService(IUtility.class));

// 2. Scoped Lifetime:
Assert.areEqual(    // the same service is returned from providerA
    providerA.getService(ILogger.class),
    providerA.getService(ILogger.class));

Assert.areNotEqual( // different services are returned from providerA and providerB
    providerA.getService(ILogger.class),
    providerB.getService(ILogger.class));

// 3. Transient Lifetime:
Assert.areNotEqual( // different services are returned from providerA
    providerA.getService(IAccountService.class),
    providerA.getService(IAccountService.class));
```

### 2.2 Register with Concrete Types

Sometimes it is **OK** for classes to be registered with concrete types instead of interfaces, such as a `Utility` class.

```java
DI.ServiceProvider provider = DI.services()
    .addSingleton('Utility')
    .addSingleton('Utility', 'Utility')               // equivalent to above
    .addSingleton('Constants')
    .addSingleton('Constants', 'Constants')           // equivalent to above
    .BuildServiceProvider();

Utility utility = (Utility) provider.getService(Utility.class);
```

### 2.3 Service Override

When multiple services of the same interface are registered, only the last one will be resolved.

```java
public interface ILogger { void error(); void warn(); }
public class EmailLogger implements ILogger {}
public class TableLogger implements ILogger {}
public class AWSS3Logger implements ILogger {}

DI.ServiceProvider provider = DI.services()
    .addSingleton('ILogger', 'EmailLogger')
    .addSingleton('ILogger', 'TableLogger')
    .addSingleton('ILogger', 'AWSS3Logger') // will override ealier registered ILogger
    .BuildServiceProvider();

ILogger logger = (ILogger) provider.getService(ILogger.class)
Assert.isTrue(logger instanceof AWSS3Logger);
```

## 3. Factory

### 3.1 Factory Class

Here is an example about how to implement `DI.ServiceFactory` to achieve constructor injection.

```java
// 1. Service Factory
public class AccountServiceFactory implements DI.ServiceFactory {
    public IAccountService newInstance(Type servcieType, DI.ServiceProvider provider) {
        return new AccountService((ILogger) provider.getService(ILogger.class));
    }
}

// 2. Factory Registrition
DI.ServiceProvider provider = DI.services()
    .addTransientFactory('IAccountService', 'AccountServiceFactory')
    .addSingleton('ILogger', 'TableLogger')
    .BuildServiceProvider();

// 3. Servcie Resolution
IAccountService accountService = (IAccountService) provider.getService(IAccountService.class);
```

### 3.2 Factory Inner Class

We can also define the factory as an inner class of the service. And even better the constructor can be defined as private to enhance the encapsulation.

```java
public with sharing class AccountService implements IAccountService {
    private ILogger logger { get; set; }

    // private constructor
    private AccountService(ILogger logger) {
        this.logger = logger;
    }

    // factory declared as inner class
    public class Factory implements DI.ServiceFactory {
        public IAccountService newInstance(Type servcieType, DI.ServiceProvider provider) {
            return new AccountService((ILogger) provider.getService(ILogger.class));
        }
    }
}

DI.ServiceProvider provider = DI.services()
    .addTransientFactory('IAccountService', 'AccountService.Factory')
    .addSingleton('ILogger', 'AWSS3Logger')
    .BuildServiceProvider();
```

### 3.3 Generic Factory

Generic service enables reusing the same factory and a template class to create a family of services.

```java
public class EmailWriter implements IEmailWriter, IWriter { ... }
public class TableWriter implements ITableWriter, IWriter { ... }
public class AWSS3Writer implements IAWSS3Writer, IWriter { ... }

public class Logger implements ILogger {
    private IWriter writer { get; set; }
    public Logger(IWriter writer) { this.writer = writer; }
    public void log(String message) {
        this.writer.write(message);
    }
}

// declare generic service factory
public class LoggerFactory implements DI.GenericServiceFactory {
    public ILogger newInstance(Type servcieType, DI.ServiceProvider provider, List<Type> parameterTypes) {
        Type writer = parameterTypes[0];
	    return new Logger((IWriter) provider.getService(writer));
    }
}

DI.ServiceProvider provider = DI.services()
    .addSingleton('IEmailWriter', 'EmailWriter')
    .addSingleton('ITableWriter', 'TableWriter')
    .addSingleton('IAWSS3Writer', 'AWSS3Writer')
    .addSingletonFactory('ILogger', 'LoggerFactory<Logger>')
    .BuildServiceProvider();

ILogger emailLogger = (ILogger) provider.getService('ILogger<IEmailWriter>');
ILogger tableLogger = (ILogger) provider.getService('ILogger<ITableWriter>');
ILogger awss3Logger = (ILogger) provider.getService('ILogger<IAWSS3Writer>');
```

## 4. Modules

It is highly recommended to use a `DI.Module` to manage service registrations, so it can help:

- Create boundaries to limit number of services registered into current module.
- Create dependencies to increase the reusability of services in other modules.

### 4.1 Module Creation

```java
public class LogModule extends DI.Module {
    public override void configure(DI.ServiceCollection services) {
        services.addSingleton('ILogger', 'AWSS3Logger');
    }
}

// use module to resolve services
DI.Module logModule = DI.modules().get(LogModule.class);
ILogger logger = (ILogger) logModule.getServcie(ILogger.class);
```

### 4.2 Module Dependencies

A module can also have dependencies on the other modules. For example, the following `SalesModule` depends on a `LogModule`. So `ILogger` service can also be resolved inside `SalesModule`.

```java
public class SalesModule extends DI.Module {
    // declare module dependencies
    public override void import(DI.ModuleCollection modules) {
        modules.add('LogModule');
    }

    public override void configure(DI.ServiceCollection services) {
        services
            .addSingleton('IAccountRepository', 'AccountRepository')
            .addTransient('IAccountService', 'AccountService');
    }
}
```

<p><img src="./docs/images/module-resolve-order.png#2023-3-15" align="right" width="200" alt="Module Resolve Order"> Module dependencies are resolved as "Last-In, First-Out" order. For example on the diagram, module 1 depends on module 5 and 2, and module 2 depends on module 4 and 3. The last registered module always take precedence over the prior ones, therefore services will be resolved in order from module 1 to 5.
</p>


```java
public class Module1 extends DI.Module {
    public override void import(DI.ModuleCollection modules) {
        modules.add('Module5');
        modules.add('Module2');
    }
}

public class Module2 extends DI.Module {
    public override void import(DI.ModuleCollection modules) {
        modules.add('Module4');
        modules.add('Module3');
    }

    public override void configure(DI.ServiceCollection services) {
        services.addTransient('ILogger', 'TableLogger');
    }
}

public class Module3 extends DI.Module {
    public override void configure(DI.ServiceCollection services) {
        services.addTransient('ILogger', 'EmailLogger');
    }
}

// module1 realizes TableLogger because module2 is registered after 3
DI.Module module1 = DI.modules().get(Module1.class);
ILogger logger1 = (ILogger) module1.getService(ILogger.class);
Assert.isTrue(logger1 instanceof TableLogger);

// module3 still realizes EmailLogger and its boundary is intact
DI.Module module3 = DI.modules().get(Module3.class);
ILogger logger3 = (ILogger) module3.getService(ILogger.class);
Assert.isTrue(logger3 instanceof EmailLogger);
```

### 4.3 Module File Structure

When project becomes huge, divide modules into different folders as below.

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

## 5. Tests

### 5.1 Test with Service Mockup

The following `AccountService` depends on  `ILogger` to function. A simple `DI.ServiceProvider` enable us to provide a `NullLogger` to silence the logging messages.

```java
@isTest
public class AccountServiceTest {
    @isTest
    static void testGetAccounts() {
        DI.ServiceProvider provider = DI.services()
            .addTransientFactory('IAccountService', 'AccountService.Factory')
            .addSingleton('ILogger', 'AccountServiceTest.NullLogger')
            .BuildServiceProvider();

        IAccountService accountService = (IAccountService.class) provider.getService(IAccountService.class);
        List<Account> accounts = accountService.getAccounts(3);
        Assert.areEqual(3, accounts.size());
    }

    public class NullLogger implements ILogger {
        public void log(Object message) {
            // a null logger silence the logging service during testing
        }
    }
}
```

### 5.2 Test with Module Mockup

Here we try to provide a mockup `SalesModule` used in the top `AccountController`.

1. Use `DI.modules().replace()` API to replace `SalesModule` with the `MockSalesModule`. **Note**: `DI.modules().replace()` must be called before the first reference of the `AccountController` class, when static initializer has not been executed.
1. Extend `SalesModule` with `MockSalesModule`. **Note**: both the `SalesModule` class and its `configure(services)` method need to be declared as `virtual` prior.
1. Use `services.addTransient` to override `IAccountService` with the `MockAccountService` inner class.

```java
@isTest
public class AccountControllerTest {
    @isTest
    static void testGetAccounts() {
        DI.modules().replace(SalesModule.class, MockSalesModule.class);    // #1
        List<Account> accounts = AccountController.getAccounts(3);
        Assert.areEqual(3, accounts.size());
    }

    public class MockSalesModule extends SalesModule {                     // #2
        protected override void configure(DI.ServiceCollection services) { // #3
            super.configure(services);
            services.addTransient('IAccountService', 'AccountControllerTest.MockAccountService');
        }
    }

    public class MockAccountService implements IAccountService {           // the mockup service
        public List<Account> getAccounts(Integer top) {
            return new List<Account>{ new Account(), new Account(), new Account() };
        }
    }
}
```

## 6. API Reference

Most of the APIs are ported from .Net Core Dependency Injection framework.

### 6.1 DI Class

| Static Methods                           | Description                                   |
| ---------------------------------------- | --------------------------------------------- |
| `DI.ServiceCollection DI.services()`     | Create an instance of `DI.ServiceCollection`. |
| `DI.GlobalModuleCollection DI.modules()` | Return `DI.GlobalModuleCollection` singleton. |

### 6.2 DI.ServiceCollection Interface

| Methods                                                                                    | Description                                                                                                        |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| `DI.ServiceProvider buildServiceProvider()`                                                | Create `DI.ServiceProvider` with services registered into the container.                                           |
| **Transient**                                                                              |                                                                                                                    |
| `DI.ServiceCollection addTransient(String serviceTypeName)`                                | Register a transient type against its own type.                                                                    |
| `DI.ServiceCollection addTransient(String serviceTypeName, String implementationTypeName)` | Register a transient type against its descendent types.                                                            |
| `DI.ServiceCollection addTransientFactory(String serviceTypeName, String factoryTypeName)` | Register a transient type against its factory type.                                                                |
| `DI.ServiceCollection addTransient(String serviceTypeName, Object instance)`               | Register a transient type against an instance. **Note**: only use this in test class to register a mockup service. |
| **Scoped**                                                                                 |                                                                                                                    |
| `DI.ServiceCollection addScoped(String serviceTypeName)`                                   | Register a scoped type against its own type.                                                                       |
| `DI.ServiceCollection addScoped(String serviceTypeName, String implementationTypeName)`    | Register a scoped type against its descendent types.                                                               |
| `DI.ServiceCollection addScopedFactory(String serviceTypeName, String factoryTypeName)`    | Register a scoped type against its factory type.                                                                   |
| `DI.ServiceCollection addScoped(String serviceTypeName, Object instance)`                  | Register a scoped type against an instance. **Note**: only use this in test class to register a mockup service.    |
| **Singleton**                                                                              |                                                                                                                    |
| `DI.ServiceCollection addSingleton(String serviceTypeName)`                                | Register a singleton type against its own type.                                                                    |
| `DI.ServiceCollection addSingleton(String serviceTypeName, String implementationTypeName)` | Register a singleton type against its descendent types.                                                            |
| `DI.ServiceCollection addSingletonFactory(String serviceTypeName, String factoryTypeName)` | Register a singleton type against its factory type.                                                                |
| `DI.ServiceCollection addSingleton(String serviceTypeName, Object instance)`               | Register a singleton type against an instance, i.e. a constant value.                                              |

### 6.3 DI.ServiceProvider Interface

| Methods                                 | Description                                |
| --------------------------------------- | ------------------------------------------ |
| `Object getService(Type serviceType)`   | Get a single service of the supplied type. |
| `Object getService(String serviceName)` | Get a single service of the supplied name. |

### 6.4 Service Factory Interface

| DI.ServiceFactory Methods                                    | Description                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `Object newInstance(Type serviceType, DI.ServiceProvider provider)` | Use the `serviceProvider` to get the instances of the services defined in the scope. Use `serviceType` in a condition to return polymorphism instances. |

| DI.GenericServiceFactory Methods                             | Description                              |
| ------------------------------------------------------------ | ---------------------------------------- |
| `Object newInstance(Type serviceType, DI.ServiceProvider provider, List<Type> parameterTypes)` | Additional `parameterTypes` is provided. |

### 6.5 DI.Module Abstract Class

| Methods                                                            | Description                                                                |
| ------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| `protected override void import(DI.ModuleCollection modules)`      | Override this method to import other module services into this module.     |
| `protected override void configure(DI.ServiceCollection services)` | [**Required**] Override this method to register services into this module. |

### 6.6 DI.GlobalModuleCollection Interface

| Static Methods                                          | Description                                            |
| ------------------------------------------------------- | ------------------------------------------------------ |
| `DI.Module get(string moduleName)`                      | Create and return a singleton module.                  |
| `DI.Module get(Type moduleType)`                        | Create and return a singleton module.                  |
| `void replace(String moduleName, String newModuleName)` | Replace existing module with another one in unit test. |
| `void replace(Type moduleType, Type newModuleType)`     | Replace existing module with another one in unit test. |

## 7. License

Apache 2.0

