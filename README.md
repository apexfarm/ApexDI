# Apex DI

![](https://img.shields.io/badge/version-3.4.0-brightgreen.svg) ![](https://img.shields.io/badge/build-passing-brightgreen.svg) ![](https://img.shields.io/badge/coverage-99%25-brightgreen.svg)

A lightweight Apex dependency injection framework inspired by .NET Core. It helps you:

1. Adopt best practices for dependency injection:
   - Decouple implementations and program against abstractions.
   - Write code that is highly reusable, extensible, and testable.
2. Organize your project with a modular structure:
   - Define boundaries to prevent loading unused services into a module.
   - Create dependencies to improve service reusability across modules.

| Environment           | Installation Link                                                                                                                                         | Version   |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| Production, Developer | <a target="_blank" href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tGC000007TPs7YAG"><img src="docs/images/deploy-button.png"></a> | ver 3.4.0 |
| Sandbox               | <a target="_blank" href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04tGC000007TPs7YAG"><img src="docs/images/deploy-button.png"></a>  | ver 3.4.0 |

---

### Translations

- [简体中文](docs/README.zh-CN.md)

### **Release Notes**

**v3.4**:

- [Pseudo Module](#42-pseudo-module): Services configured with custom metadata types can be directly loaded as a singleton pseudo module.

**v3.3**:

- Upgraded to API version 64.0.
- [Service Registry](#24-service-registry): Services can be configured with custom metadata types now.

**v3.1**:

- [Service Factory Interface](#64-service-factory-interface) parameter order changes:
  - `newInstance(DI.ServiceProvider provider, Type serviceType)`
  - `newInstance(DI.ServiceProvider provider, Type serviceType, List<String> parameterNames)`

---

Here is an example controller that uses `DI.Module` to resolve services. As you can see, the controller does not depend on any concrete types, making it thin and clean!

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
  - [2.4 Service Registry](#24-service-registry)
- [3. Factory](#3-factory)
  - [3.1 Factory Class](#31-factory-class)
  - [3.2 Factory Inner Class](#32-factory-inner-class)
  - [3.3 Generic Factory](#33-generic-factory)
- [4. Modules](#4-modules)
  - [4.1 Module Creation](#41-module-creation)
  - [4.2 Pseudo Module](#42-pseudo-module)
  - [4.3 Module Dependencies](#43-module-dependencies)
  - [4.4 Module File Structure](#44-module-file-structure)
- [5. Tests](#5-tests)
  - [5.1 Test with Service Mockup](#51-test-with-service-mockup)
  - [5.2 Test with Module Mockup](#52-test-with-module-mockup)
- [6. API Reference](#6-api-reference)
  - [6.1 DI Class](#61-di-class)
  - [6.2 DI.ServiceCollection](#62-diservicecollection)
  - [6.3 DI.ServiceProvider](#63-diserviceprovider)
  - [6.4 Service Factory](#64-service-factory)
  - [6.5 DI.Module](#65-dimodule)
  - [6.6 DI.GlobalModuleCollection](#66-diglobalmodulecollection)
- [7. License](#7-license)

## 1. Performance

<p align="center"><img src="./docs/images/benchmark.png" width=650 alt="Performance Benchmark"></p>

1. Service registration with class names is currently the fastest solution, compared to strong class types. They almost cost nothing (**green color line**).
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

### 2.4 Service Registry

<p align="center"><img src="./docs/images/registry.png" width=800 alt="DI Registry"></p>

Services can also be registered using `DIRegistry__mdt`. To load all services in the `DITest::*` group, use the `addFromRegistry` API. This method also works with the `DI.Module` configuration. **Note**: Implementation by a factory should have names ending with the `Factory` suffix.

```java
DI.ServiceProvider provider = DI.services()
    .addFromRegistry('DITest') // service group prefix
    .buildServiceProvider();
```

A service group name serves as a logical namespace, such as `group::subgroup`. If you do not need to load all services within a group, you can target a specific subgroup as shown below. While registry-based registration can be combined with code-based registration, services from the registry are always loaded before those registered in code.

```java
DI.ServiceProvider provider = DI.services()
    .addFromRegistry('DITest::Group1')                 // service group prefix
    .addScoped('DITest.ILogger', 'DITest.TableLogger') // code-based registration
    .buildServiceProvider();
```

Multiple groups may be loaded simultaneously. Note that the order in which groups are loaded is important—services from the last loaded group will override any identically named services from previously loaded groups.

```java
DI.ServiceProvider provider = DI.services()
    .addFromRegistry('GroupA')
    .addFromRegistry('GroupB')
    .addFromRegistry('GroupC')
    .buildServiceProvider();
```

## 3. Factory

### 3.1 Factory Class

Here is an example of how to implement `DI.ServiceFactory` to achieve constructor injection.

```java
// 1. Service Factory
public class AccountServiceFactory implements DI.ServiceFactory {
    public IAccountService newInstance(DI.ServiceProvider provider, Type serviceType) {
        return new AccountService((ILogger) provider.getService(ILogger.class));
    }
}

// 2. Factory Registration
DI.ServiceProvider provider = DI.services()
    .addTransientFactory('IAccountService', 'AccountServiceFactory')
    .addSingleton('ILogger', 'TableLogger')
    .BuildServiceProvider();

// 3. Service Resolution
IAccountService accountService = (IAccountService) provider.getService(IAccountService.class);
```

### 3.2 Factory Inner Class

You can also define the factory as an inner class of the service. The constructor can be private to enhance encapsulation.

```java
public with sharing class AccountService implements IAccountService {
    private ILogger logger { get; set; }

    // private constructor
    private AccountService(ILogger logger) {
        this.logger = logger;
    }

    // factory declared as inner class
    public class Factory implements DI.ServiceFactory {
        public IAccountService newInstance(DI.ServiceProvider provider, Type serviceType) {
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

A generic service enables you to reuse the same factory and a template class to create a family of services.

```java
public class EmailWriter implements IEmailWriter, IWriter { ... }
public class TableWriter implements ITableWriter, IWriter { ... }
public class AWSS3Writer implements IAWSS3Writer, IWriter { ... }

public class Logger implements ILogger {
    private IWriter writer { get; set; }                     // dependency
    public Logger(IWriter writer) { this.writer = writer; }  // constructor
    public void log(String message) {                        // method
        this.writer.write(message);
    }
}

// declare generic service factory
public class LoggerFactory implements DI.GenericServiceFactory {
    public ILogger newInstance(DI.ServiceProvider provider, Type serviceType,
        List<String> parameterNames) {
        String writerName = parameterNames[0];
        return new Logger((IWriter) provider.getService(writerName));
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

It is highly recommended to use a `DI.Module` to manage service registrations. This approach helps you:

- Create boundaries to limit the number of services registered in the current module.
- Define dependencies to increase the reusability of services across modules.

### 4.1 Module Creation

A module is a singleton, meaning that calling `DI.modules().get()` with the same type always returns the same instance.

```java
public class LogModule extends DI.Module {
    public override void configure(DI.ServiceCollection services) {
        services.addSingleton('ILogger', 'AWSS3Logger');
    }
}

// Use the module to resolve services
DI.Module logModule = DI.modules().get(LogModule.class);
ILogger logger = (ILogger) logModule.getService(ILogger.class);
```

### 4.2 Pseudo Module

You can load a registry service group directly as a singleton `DI.Module` by passing `Pseudo<Service Group Prefix>`. Multiple service groups can also be combined into a single pseudo module.

<p align="center"><img src="./docs/images/registry.png" width=800 alt="DI Registry"></p>

```java
DI.Module moduleA = DI.modules().get('Pseudo<DITest>');
DI.Module moduleB = DI.modules().get('Pseudo<DITest>');
Assert.areEqual(moduleA, moduleB); // The same module instance is returned

DI.Module moduleC = DI.modules().get('Pseudo<DITest::Group1, DITest::Group2, DITest::Group3>');
Assert.areNotEqual(moduleC, moduleB);
```

### 4.3 Module Dependencies

A module can also have dependencies on other modules. For example, the following `SalesModule` depends on a `LogModule`, so the `ILogger` service can also be resolved inside `SalesModule`.

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

<p><img src="./docs/images/module-resolve-order.png#2023-3-15" align="right" width="200" alt="Module Resolve Order"> Module dependencies are resolved in "Last-In, First-Out" order. For example, in the diagram, services will be resolved in the order from module 1 to 5.
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

// module1 resolves TableLogger because module2 is registered after module3
DI.Module module1 = DI.modules().get(Module1.class);
ILogger logger1 = (ILogger) module1.getService(ILogger.class);
Assert.isTrue(logger1 instanceof TableLogger);

// module3 still resolves EmailLogger and its boundary is intact
DI.Module module3 = DI.modules().get(Module3.class);
ILogger logger3 = (ILogger) module3.getService(ILogger.class);
Assert.isTrue(logger3 instanceof EmailLogger);
```

### 4.4 Module File Structure

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

The following `AccountService` depends on `ILogger` to function. A simple `DI.ServiceProvider` enable us to provide a `NullLogger` to silence the logging messages.

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

### 6.2 DI.ServiceCollection

| Methods                                                                                    | Description                                                                                                        |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| `DI.ServiceProvider buildServiceProvider()`                                                | Create `DI.ServiceProvider` with services registered into the container.                                           |
| `DI.ServiceProvider addFromRegistry(String serviceGroupPrefix)`                            | Register all services from `DIRegistry__mdt` with a group name prefix.                                             |
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

### 6.3 DI.ServiceProvider

| Methods                                 | Description                                |
| --------------------------------------- | ------------------------------------------ |
| `Object getService(Type serviceType)`   | Get a single service of the supplied type. |
| `Object getService(String serviceName)` | Get a single service of the supplied name. |

### 6.4 Service Factory

| DI.ServiceFactory Interface                                         | Description                                                                                                                                             |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Object newInstance(DI.ServiceProvider provider, Type serviceType)` | Use the `serviceProvider` to get the instances of the services defined in the scope. Use `serviceType` in a condition to return polymorphism instances. |

| DI.GenericServiceFactory Interface                                                               | Description                              |
| ------------------------------------------------------------------------------------------------ | ---------------------------------------- |
| `Object newInstance(DI.ServiceProvider provider, Type serviceType, List<String> parameterNames)` | Additional `parameterTypes` is provided. |

### 6.5 DI.Module

| Methods                                                            | Description                                                                |
| ------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| `protected override void import(DI.ModuleCollection modules)`      | Override this method to import other module services into this module.     |
| `protected override void configure(DI.ServiceCollection services)` | [**Required**] Override this method to register services into this module. |

### 6.6 DI.GlobalModuleCollection

| Static Methods                                          | Description                                            |
| ------------------------------------------------------- | ------------------------------------------------------ |
| `DI.Module get(string moduleName)`                      | Create and return a singleton module.                  |
| `DI.Module get(Type moduleType)`                        | Create and return a singleton module.                  |
| `void replace(String moduleName, String newModuleName)` | Replace existing module with another one in unit test. |
| `void replace(Type moduleType, Type newModuleType)`     | Replace existing module with another one in unit test. |

## 7. License

Apache 2.0
