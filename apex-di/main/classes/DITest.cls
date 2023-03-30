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
 * See the License for the specific language governing permissions ands
 * limitations under the License.
 */

@IsTest
public class DITest {
    // ================
    // #region Services

    @IsTest
    static void test_services_lifetime() {
        DI.ServiceProvider providerA = DI.services()
            .addSingleton('DITest.IUtility', 'DITest.Utility')
            .addScoped('DITest.ILogger', 'DITest.TableLogger')
            .addTransient('DITest.IAccountService', 'DITest.AccountService')
            .BuildServiceProvider();

        DI.ServiceProvider providerB = DI.services()
            .addSingleton('DITest.IUtility', 'DITest.Utility')
            .addScoped('DITest.ILogger', 'DITest.TableLogger')
            .addTransient('DITest.IAccountService', 'DITest.AccountService')
            .BuildServiceProvider();

        Assert.areNotEqual(null, providerA.getService(IUtility.class));
        Assert.areNotEqual(null, providerB.getService(IUtility.class));
        Assert.areEqual(providerA.getService(IUtility.class), providerA.getService(IUtility.class));
        Assert.areEqual(providerB.getService(IUtility.class), providerB.getService(IUtility.class));
        Assert.areEqual(providerA.getService(IUtility.class), providerB.getService(IUtility.class));

        Assert.areNotEqual(null, providerA.getService(ILogger.class));
        Assert.areNotEqual(null, providerB.getService(ILogger.class));
        Assert.areEqual(providerA.getService(ILogger.class), providerA.getService(ILogger.class));
        Assert.areEqual(providerB.getService(ILogger.class), providerB.getService(ILogger.class));
        Assert.areNotEqual(providerA.getService(ILogger.class), providerB.getService(ILogger.class));

        Assert.areNotEqual(null, providerA.getService(IAccountService.class));
        Assert.areNotEqual(null, providerB.getService(IAccountService.class));
        Assert.areNotEqual(providerA.getService(IAccountService.class), providerA.getService(IAccountService.class));
        Assert.areNotEqual(providerB.getService(IAccountService.class), providerB.getService(IAccountService.class));
        Assert.areNotEqual(providerA.getService(IAccountService.class), providerB.getService(IAccountService.class));
    }

    @IsTest
    static void test_services_lifetime_singleton_caveat() {
        // Provider A
        DI.ServiceProvider providerA = DI.services()
            .addSingleton('DITest.IUtility', 'DITest.Utility')
            .BuildServiceProvider();

        IUtility util = (IUtility) providerA.getService(IUtility.class);
        Assert.isTrue(util instanceof Utility);

        // Provider B
        DI.ServiceProvider providerB = DI.services()
            .addSingleton('DITest.IUtility', 'DITest.AnotherUtility')
            .BuildServiceProvider();

        IUtility anotherUtil = (IUtility) providerB.getService(IUtility.class);
        Assert.isFalse(anotherUtil instanceof AnotherUtility);
        Assert.areEqual(anotherUtil, util);

        // Provider C
        DI.ServiceProvider providerC = DI.services()
            .addScoped('DITest.IUtility', 'DITest.AnotherUtility')
            .BuildServiceProvider();

        IUtility anotherUtil2 = (IUtility) providerC.getService(IUtility.class);
        Assert.isTrue(anotherUtil2 instanceof AnotherUtility);
        Assert.isTrue(anotherUtil2 != util);
    }

    @IsTest
    static void test_services_concrete_types() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.TableLogger')
            .addScoped('DITest.EmailLogger')
            .addTransient('DITest.AWSS3Logger')
            .BuildServiceProvider();

        ILogger tableLogger = (ILogger) provider.getService(TableLogger.class);
        ILogger emailLogger = (ILogger) provider.getService(EmailLogger.class);
        ILogger awss3Logger = (ILogger) provider.getService(AWSS3Logger.class);

        Assert.isTrue(awss3Logger instanceof AWSS3Logger);
        Assert.isTrue(emailLogger instanceof EmailLogger);
        Assert.isTrue(tableLogger instanceof TableLogger);
    }

    @IsTest
    static void test_services_enumerable() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.ILogger', 'DITest.TableLogger')
            .addScoped('DITest.ILogger', 'DITest.EmailLogger')
            .addTransient('DITest.ILogger', 'DITest.AWSS3Logger')
            .BuildServiceProvider();

        List<ILogger> loggers = (List<ILogger>) provider.getServices(ILogger.class);

        Assert.areEqual(3, loggers.size());

        Assert.isTrue(loggers[0] instanceof AWSS3Logger);
        Assert.isTrue(loggers[1] instanceof EmailLogger);
        Assert.isTrue(loggers[2] instanceof TableLogger);

        ILogger logger = (ILogger) provider.getService(ILogger.class);
        Assert.isTrue(logger instanceof AWSS3Logger);
    }

    @IsTest
    static void test_services_internal_serviceProvider() {
        DI.ServiceProvider providerA = DI.services()
            .addSingleton('DITest.IUtility', 'DITest.Utility')
            .addScoped('DITest.ILogger', 'DITest.TableLogger')
            .addTransient('DITest.IAccountService', 'DITest.AccountService')
            .BuildServiceProvider();

        DI.ServiceProvider providerB = (DI.ServiceProvider) providerA.getService(DI.ServiceProvider.class);

        DI.ServiceProvider providerC = ((DI.ServiceScopeFactory) providerB).createScope().getServiceProvider();

        Assert.areEqual(providerA.getService(ILogger.class), providerB.getService(ILogger.class));
        Assert.areNotEqual(providerA.getService(ILogger.class), providerC.getService(ILogger.class));
        Assert.areNotEqual(providerB.getService(ILogger.class), providerC.getService(ILogger.class));
    }

    public interface IUtility {
    }

    public class Utility implements IUtility {
    }

    public class AnotherUtility implements IUtility {
    }

    public interface ILogger {
        void log(String message);
    }

    public class TableLogger implements ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('Table: ' + message);
        }
    }

    public class EmailLogger implements ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('Email: ' + message);
        }
    }

    public class AWSS3Logger implements ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('AWSS3: ' + message);
        }
    }

    public class NullLogger implements ILogger {
        public void log(String message) {
        }
    }

    public interface IAccountService {
    }

    public class AccountService implements IAccountService {
        private List<ILogger> logger { get; set; }
        private GlobalConfiguration configuration { get; set; }

        public AccountService() {
        }

        public AccountService(List<ILogger> logger, GlobalConfiguration confiragion) {
            this.logger = logger;
            this.configuration = configuration;
        }
    }

    // #endregion
    // ================

    // =================
    // #region Factories
    @IsTest
    static void test_factories() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.GlobalConfiguration', new GlobalConfiguration())
            .addSingleton('DITest.ILogger', 'DITest.TableLogger')
            .addSingleton('DITest.ILogger', 'DITest.EmailLogger')
            .addSingletonFactory('DITest.ILogger', 'DITest.AWSS3LoggerFactory')
            .addTransientFactory('DITest.IAccountService', 'DITest.AccountServiceFactory')
            .BuildServiceProvider();

        IAccountService accountService = (IAccountService) provider.getService(IAccountService.class);
        Assert.areNotEqual(null, accountService);
        Assert.isTrue(accountService instanceof AccountService);
    }

    @IsTest
    static void test_factories_generic() {
        DI.ServiceProvider provider = DI.services()
            .addSingletonFactory('DITest.ILogger', 'DITest.LoggerFactory')
            .addSingletonFactory('DITest.ILogger', 'DITest.LoggerFactory<DITest.TableLogger>')
            .addSingletonFactory('DITest.ILogger', 'DITest.LoggerFactory<DITest.EmailLogger>')
            .addSingletonFactory('DITest.ILogger', 'DITest.LoggerFactory<DITest.AWSS3Logger>')
            .buildServiceProvider();

        List<ILogger> logger = (List<ILogger>) provider.getServices(ILogger.class);

        Assert.areEqual(4, logger.size());

        Assert.isTrue(logger[0] instanceof AWSS3Logger);
        Assert.isTrue(logger[1] instanceof EmailLogger);
        Assert.isTrue(logger[2] instanceof TableLogger);
        Assert.isTrue(logger[3] instanceof NullLogger);
    }

    @IsTest
    static void test_factories_generic_services() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.IEmailWriter', 'DITest.EmailWriter')
            .addSingleton('DITest.ITableWriter', 'DITest.TableWriter')
            .addSingleton('DITest.IAWSS3Writer', 'DITest.AWSS3Writer')
            .addSingletonFactory('DITest.ILogger', 'DITest.GenericLoggerFactory<DITest.Logger>')
            .BuildServiceProvider();

        Logger emailLogger = (Logger) provider.getService('DITest.ILogger<DITest.IEmailWriter>');
        Logger tableLogger = (Logger) provider.getService('DITest.ILogger<DITest.ITableWriter>');
        Logger awss3Logger = (Logger) provider.getService('DITest.ILogger<DITest.IAWSS3Writer>');

        Assert.isTrue(emailLogger.writer instanceof IEmailWriter);
        Assert.isTrue(tableLogger.writer instanceof ITableWriter);
        Assert.isTrue(awss3Logger.writer instanceof IAWSS3Writer);
        Assert.areEqual(emailLogger, provider.getService('DITest.ILogger<DITest.IEmailWriter>'));
        Assert.areEqual(tableLogger, provider.getService('DITest.ILogger<DITest.ITableWriter>'));
        Assert.areEqual(awss3Logger, provider.getService('DITest.ILogger<DITest.IAWSS3Writer>'));
    }

    @IsTest
    static void test_factories_generic_services_enumerable() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.IEmailWriter', 'DITest.EmailWriter')
            .addSingleton('DITest.ITableWriter', 'DITest.TableWriter')
            .addSingleton('DITest.IAWSS3Writer', 'DITest.AWSS3Writer')
            .addSingletonFactory('DITest.ILogger', 'DITest.GenericLoggerFactory<DITest.Logger>')
            .addSingletonFactory('DITest.ILogger', 'DITest.GenericLoggerFactory<DITest.Logger>')
            .BuildServiceProvider();

        List<ILogger> emailLoggers = (List<ILogger>) provider.getServices('DITest.ILogger<DITest.IEmailWriter>');
        List<ILogger> tableLoggers = (List<ILogger>) provider.getServices('DITest.ILogger<DITest.ITableWriter>');
        List<ILogger> awss3Loggers = (List<ILogger>) provider.getServices('DITest.ILogger<DITest.IAWSS3Writer>');

        Assert.areEqual(2, emailLoggers.size());
        Assert.areEqual(2, tableLoggers.size());
        Assert.areEqual(2, awss3Loggers.size());
    }

    // ! Comment out before release, so no dependencies to standard SObjects such as Account and Contact!
    // TODO: Comment out before release, so no dependencies to standard SObjects such as Account and Contact!
    @IsTest
    static void test_factories_generic_services_sobjects() {
        DI.ServiceProvider provider = DI.services()
            .addSingletonFactory('DITest.IRepository', 'DITest.RepositoryFactory<DITest.Repository>')
            .BuildServiceProvider();

        Repository repository = (Repository) provider.getService('DITest.IRepository<Account, Contact>');
        Assert.areEqual(2, repository.sobjectTypes.size());
        Assert.areEqual(Account.SObjectType, repository.sobjectTypes[0]);
        Assert.areEqual(Contact.SObjectType, repository.sobjectTypes[1]);
        throw new NoSuchElementException('Comment out before release!');
    }

    public class GlobalConfiguration {
    }

    public class AccountServiceFactory implements DI.ServiceFactory {
        public IAccountService newInstance(Type serviceType, DI.ServiceProvider provider) {
            return new AccountService(
                (List<ILogger>) provider.getServices(ILogger.class),
                (GlobalConfiguration) provider.getService(GlobalConfiguration.class)
            );
        }
    }

    public class AWSS3LoggerFactory implements DI.ServiceFactory {
        public Object newInstance(Type serviceType, DI.ServiceProvider serviceProvider) {
            return new AWSS3Logger();
        }
    }

    public class LoggerFactory implements DI.ServiceFactory {
        public ILogger newInstance(Type serviceType, DI.ServiceProvider serviceProvider) {
            if (serviceType == AWSS3Logger.class) {
                return new AWSS3Logger();
            } else if (serviceType == EmailLogger.class) {
                return new EmailLogger();
            } else if (serviceType == TableLogger.class) {
                return new TableLogger();
            }
            return new NullLogger();
        }
    }

    public interface IWriter {
        void write(Object message);
    }

    public interface IEmailWriter {
    }

    public interface ITableWriter {
    }

    public interface IAWSS3Writer {
    }

    public class EmailWriter implements IEmailWriter, IWriter {
        public void write(Object message) {
        }
    }

    public class TableWriter implements ITableWriter, IWriter {
        public void write(Object message) {
        }
    }

    public class AWSS3Writer implements IAWSS3Writer, IWriter {
        public void write(Object message) {
        }
    }

    public class Logger implements ILogger {
        private IWriter writer { get; set; }

        public Logger() {
        }

        public Logger(IWriter writer) {
            this.writer = writer;
        }

        public void log(String message) {
            this.writer.write(message);
        }
    }

    public class GenericLoggerFactory implements DI.GenericServiceFactory {
        public ILogger newInstance(Type servcieType, List<Type> genericTypes, DI.ServiceProvider provider) {
            System.debug(genericTypes);
            Type writerType = genericTypes[0];
            return new Logger((IWriter) provider.getService(writerType));
        }
    }

    public interface IRepository {
    }

    public class Repository implements IRepository {
        private List<SObjectType> sobjectTypes { get; set; }

        public Repository(List<SObjectType> sobjectTypes) {
            this.sobjectTypes = sobjectTypes;
        }
    }

    public class RepositoryFactory implements DI.GenericServiceFactory {
        public IRepository newInstance(Type servcieType, List<Type> genericTypes, DI.ServiceProvider provider) {
            List<SObjectType> sobjectTypes = new List<SObjectType>();
            for (Type type : genericTypes) {
                sobjectTypes.add(((SObject) type.newInstance()).getSObjectType());
            }

            return new Repository(sobjectTypes);
        }
    }

    // #endregion
    // ================

    // ===============
    // #region Modules

    public class ModuleA extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services
                .addSingleton('DITest.IUtility', 'DITest.Utility')
                .addScoped('DITest.ILogger', 'DITest.TableLogger')
                .addTransient('DITest.IAccountService', 'DITest.AccountService');
        }
    }

    public class ModuleB extends DI.Module {
        protected override void import(DI.ModuleCollection modules) {
            modules.add('DITest.ModuleA');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    @IsTest
    static void test_modules_lifetime() {
        DI.Module moduleA = DI.getModule(ModuleA.class);
        DI.Module moduleB = DI.getModule(ModuleB.class);

        Assert.areNotEqual(null, moduleA.getService(IUtility.class));
        Assert.areNotEqual(null, moduleB.getService(IUtility.class));
        Assert.areEqual(moduleA.getService(IUtility.class), moduleA.getService(IUtility.class));
        Assert.areEqual(moduleB.getService(IUtility.class), moduleB.getService(IUtility.class));
        Assert.areEqual(moduleA.getService(IUtility.class), moduleB.getService(IUtility.class));

        Assert.areNotEqual(null, moduleA.getService(ILogger.class));
        Assert.areNotEqual(null, moduleB.getService(ILogger.class));
        Assert.areEqual(moduleA.getService(ILogger.class), moduleA.getService(ILogger.class));
        Assert.areEqual(moduleB.getService(ILogger.class), moduleB.getService(ILogger.class));
        Assert.areNotEqual(moduleA.getService(ILogger.class), moduleB.getService(ILogger.class));

        Assert.areNotEqual(null, moduleA.getService(IAccountService.class));
        Assert.areNotEqual(null, moduleB.getService(IAccountService.class));
        Assert.areNotEqual(moduleA.getService(IAccountService.class), moduleA.getService(IAccountService.class));
        Assert.areNotEqual(moduleB.getService(IAccountService.class), moduleB.getService(IAccountService.class));
        Assert.areNotEqual(moduleA.getService(IAccountService.class), moduleB.getService(IAccountService.class));
    }

    public class ModuleC extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services
                .addSingleton('DITest.ILogger', 'DITest.TableLogger')
                .addScoped('DITest.ILogger', 'DITest.EmailLogger')
                .addTransient('DITest.ILogger', 'DITest.AWSS3Logger');
        }
    }

    @IsTest
    static void test_modules_enumerable() {
        DI.Module moduleC = DI.getModule(ModuleC.class);
        List<ILogger> loggers = (List<ILogger>) moduleC.getServices(ILogger.class);

        Assert.areEqual(3, loggers.size());

        Assert.isTrue(loggers[0] instanceof AWSS3Logger);
        Assert.isTrue(loggers[1] instanceof EmailLogger);
        Assert.isTrue(loggers[2] instanceof TableLogger);

        ILogger logger = (ILogger) moduleC.getService(ILogger.class);
        Assert.isTrue(logger instanceof AWSS3Logger);
    }

    public class ModuleD extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services
                .addSingleton('DITest.IEmailWriter', 'DITest.EmailWriter')
                .addSingleton('DITest.ITableWriter', 'DITest.TableWriter')
                .addSingleton('DITest.IAWSS3Writer', 'DITest.AWSS3Writer')
                .addSingletonFactory('DITest.ILogger', 'DITest.GenericLoggerFactory<DITest.Logger>');
        }
    }

    @IsTest
    static void test_modules_generic_services() {
        DI.Module moduleD = DI.getModule(ModuleD.class);

        Logger emailLogger = (Logger) moduleD.getService('DITest.ILogger<DITest.IEmailWriter>');
        Logger tableLogger = (Logger) moduleD.getService('DITest.ILogger<DITest.ITableWriter>');
        Logger awss3Logger = (Logger) moduleD.getService('DITest.ILogger<DITest.IAWSS3Writer>');

        Assert.isTrue(emailLogger.writer instanceof IEmailWriter);
        Assert.isTrue(tableLogger.writer instanceof ITableWriter);
        Assert.isTrue(awss3Logger.writer instanceof IAWSS3Writer);
        Assert.areEqual(emailLogger, moduleD.getService('DITest.ILogger<DITest.IEmailWriter>'));
        Assert.areEqual(tableLogger, moduleD.getService('DITest.ILogger<DITest.ITableWriter>'));
        Assert.areEqual(awss3Logger, moduleD.getService('DITest.ILogger<DITest.IAWSS3Writer>'));
    }

    public class Module1 extends DI.Module {
        public override void import(DI.ModuleCollection modules) {
            modules.add('DITest.Module5');
            modules.add('DITest.Module2');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    public class Module2 extends DI.Module {
        public override void import(DI.ModuleCollection modules) {
            modules.add('DITest.Module4');
            modules.add('DITest.Module3');
        }

        public override void configure(DI.ServiceCollection services) {
            services.addTransient('DITest.ILogger', 'DITest.TableLogger');
        }
    }

    public class Module3 extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
        }
    }

    public class Module4 extends DI.Module {
        public override void configure(DI.ServiceCollection services) {
            services.addTransient('DITest.ILogger', 'DITest.EmailLogger');
        }
    }

    public class Module5 extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
        }
    }

    @IsTest
    static void test_modules_dependency() {
        DI.Module module = DI.getModule(Module1.class);
        ILogger logger = (ILogger) module.getService(ILogger.class);
        Assert.isTrue(logger instanceof TableLogger);
    }

    @IsTest
    static void test_modules_replacement() {
        DI.addModule(LogModule.class, MockupLogModule.class);
        DI.Module module = DI.getModule(LogModule.class);
        Assert.isTrue(module instanceof MockupLogModule);
    }

    @IsTest
    static void test_modules_replacement2() {
        DI.addModule('DITest.LogModule', 'DITest.MockupLogModule');
        DI.Module module = DI.getModule(LogModule.class);
        Assert.isTrue(module instanceof MockupLogModule);
    }

    @IsTest
    static void test_modules_replacement3() {
        DI.getModule(MockupSalesModule.class);
        DI.Module module = DI.getModule(LogModule.class);
        Assert.isTrue(module instanceof MockupLogModule);
    }

    public class LogModule extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services.addSingleton('DITest.ILogger', 'DITest.TableLogger');
            services.addTransient('DITest.ILogger', 'DITest.EmailLogger');
            services.addSingletonFactory('DITest.ILogger', 'DITest.AWSS3LoggerFactory');
        }
    }

    public class MockupLogModule extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services.addSingleton('DITest.ILogger', 'DITest.TableLogger');
            services.addTransient('DITest.ILogger', 'DITest.EmailLogger');
            services.addSingletonFactory('DITest.ILogger', 'DITest.AWSS3LoggerFactory');
        }
    }

    public class MockupSalesModule extends DI.Module {
        protected override void import(DI.ModuleCollection modules) {
            modules.add('DITest.LogModule', 'DITest.MockupLogModule');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    // #endregion
    // ==============

    // ==================
    // #region Exceptions

    public interface INoService {
    }

    public interface IWrongService {
    }

    public class WrongService {
        // will give error during service resolving, because it is not an implementation of IWrongService.
    }

    public interface IWrongFactory {
    }

    public class WrongFactory {
        // will give error during service resolving, because it is not factory class.
    }

    public interface IWrongLogger {
    }

    public class NullExceptionLoggerFactory implements DI.ServiceFactory {
        public ILogger newInstance(Type servcieType, DI.ServiceProvider provider) {
            Exception exp;
            try {
                Type noType = null;
                provider.getService(noType);
            } catch (DI.DIIllegalArgumentException ex) {
                exp = ex;
            }
            Assert.isTrue(exp != null);
            System.debug(exp);

            exp = null;
            try {
                Type noType = null;
                provider.getServices(noType);
            } catch (DI.DIIllegalArgumentException ex) {
                exp = ex;
            }
            Assert.isTrue(exp != null);
            System.debug(exp);

            exp = null;
            try {
                String noName = null;
                provider.getService(noName);
            } catch (DI.DIIllegalArgumentException ex) {
                exp = ex;
            }
            Assert.isTrue(exp != null);
            System.debug(exp);

            exp = null;
            try {
                String noName = null;
                provider.getServices(noName);
            } catch (DI.DIIllegalArgumentException ex) {
                exp = ex;
            }
            Assert.isTrue(exp != null);
            System.debug(exp);

            throw new NullPointerException();
        }
    }

    @IsTest
    static void test_exceptions_none() {
        DI.ServiceProvider provider = DI.services().BuildServiceProvider();

        INoService noService = (INoService) provider.getService(INoService.class);
        Assert.areEqual(null, noService);

        noService = (INoService) provider.getService('DITest.INoService');
        Assert.areEqual(null, noService);

        List<INoService> noServices = (List<INoService>) provider.getServices(INoService.class);
        Assert.areNotEqual(null, noServices);
        Assert.areEqual(0, noServices.size());

        noServices = (List<INoService>) provider.getServices('DITest.INoService');
        Assert.areNotEqual(null, noServices);
        Assert.areEqual(0, noServices.size());
    }

    @IsTest
    static void test_exceptions_hasCode() {
        GlobalConfiguration GLOBAL_CONFIGURATION = new GlobalConfiguration();
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.GlobalConfiguration', GLOBAL_CONFIGURATION)
            .addSingleton('DITest.GlobalConfiguration', GLOBAL_CONFIGURATION)
            .addSingleton('DITest.GlobalConfiguration', new GlobalConfiguration())
            .addSingleton('DITest.GlobalConfiguration', new GlobalConfiguration())
            .addSingleton('DITest.GlobalConfiguration', 'DITest.GlobalConfiguration')
            .addSingleton('DITest.GlobalConfiguration', 'DITest.GlobalConfiguration')
            .BuildServiceProvider();

        List<GlobalConfiguration> configs = (List<GlobalConfiguration>) provider.getServices(GlobalConfiguration.class);
        Assert.areEqual(6, configs.size());
        Assert.areEqual(4, DI.ROOT_MODULE.uniqueDescriptors.size());
    }

    @IsTest
    static void test_exceptions() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.GlobalConfiguration', new GlobalConfiguration())
            .addSingleton('DITest.IWrongService', 'DITest.WrongService')
            .addSingletonFactory('DITest.IWrongFactory', 'DITest.WrongFactory')
            .addSingletonFactory('DITest.IWrongLogger', 'DITest.AWSS3LoggerFactory<DITest.AWSS3Logger>')
            .addSingletonFactory('DITest.ILogger', 'DITest.NullExceptionLoggerFactory')
            .addSingletonFactory('DITest.IAccountService', 'DITest.AccountServiceFactory<DITest.IWrongLogger>')
            .BuildServiceProvider();

        Exception exp;
        try {
            Type noType = null;
            provider.getService(noType);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            Type noType = null;
            provider.getServices(noType);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            String noName = null;
            provider.getService(noName);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            String noName = null;
            provider.getServices(noName);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            provider.getService(IWrongService.class);
        } catch (DI.DITypeException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            provider.getService(IWrongFactory.class);
        } catch (DI.DITypeException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            provider.getService(ILogger.class);
        } catch (NullPointerException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            provider.getService(IAccountService.class);
        } catch (DI.DITypeException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);
    }

    @IsTest
    static void test_exceptions_modules() {
        Exception exp = null;
        try {
            DI.getModule(INoService.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.addModule(INoService.class, INoService.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.addModule(LogModule.class, INoService.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.getModule(ExceptionModule1.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.getModule(ExceptionModule2.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.getModule(ExceptionModule3.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);
    }

    public class ExceptionModule1 extends DI.Module {
        protected override void import(DI.ModuleCollection modules) {
            modules.add('DITest.INoService');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    public class ExceptionModule2 extends DI.Module {
        protected override void import(DI.ModuleCollection modules) {
            modules.add('DITest.INoService', 'DITest.INoService');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    public class ExceptionModule3 extends DI.Module {
        protected override void import(DI.ModuleCollection modules) {
            modules.add('DITest.LogModule', 'DITest.INoService');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    @IsTest
    static void test_performance() {
        DI.ServiceCollection services = DI.services();

        Datetime startTime = Datetime.now();
        Integer startCPU = Limits.getCpuTime();
        for (Integer i = 1; i <= 100; i++) {
            services.addTransient('DITest.Benchmark' + i);
        }
        Datetime endTime = Datetime.now();
        Integer endCPU = Limits.getCpuTime();
        System.debug('DI Registration Performance (Time): ' + (endTime.getTime() - startTime.getTime()));
        System.debug('DI Registration Performance (CPU): ' + (endCPU - startCPU));

        DI.ServiceProvider provider = services.buildServiceProvider();

        startTime = Datetime.now();
        startCPU = Limits.getCpuTime();
        for (Integer i = 1; i <= 100; i++) {
            provider.getService('DITest.Benchmark' + i);
        }
        endTime = Datetime.now();
        endCPU = Limits.getCpuTime();
        System.debug('DI Resolution Performance (Time): ' + (endTime.getTime() - startTime.getTime()));
        System.debug('DI Resolution Performance (CPU): ' + (endCPU - startCPU));

        startTime = Datetime.now();
        startCPU = Limits.getCpuTime();
        for (Integer i = 1; i <= 100; i++) {
            provider.getService('DITest.Benchmark' + i);
        }
        endTime = Datetime.now();
        endCPU = Limits.getCpuTime();
        System.debug('DI Resolution Performance (Time): ' + (endTime.getTime() - startTime.getTime()));
        System.debug('DI Resolution Performance (CPU): ' + (endCPU - startCPU));

        startTime = Datetime.now();
        startCPU = Limits.getCpuTime();
        for (Integer i = 0; i < 100; i++) {
            String name = 'DITest.Benchmark' + i;
            new Benchmark1();
        }
        endTime = Datetime.now();
        endCPU = Limits.getCpuTime();
        System.debug('Control Sample Performance (Time): ' + (endTime.getTime() - startTime.getTime()));
        System.debug('Control Sample Performance (CPU): ' + (endCPU - startCPU));
    }
    // #endregion
    // ==================

    // =================
    // #region Benchmark

    public class Benchmark1 {
    }
    public class Benchmark2 {
    }
    public class Benchmark3 {
    }
    public class Benchmark4 {
    }
    public class Benchmark5 {
    }
    public class Benchmark6 {
    }
    public class Benchmark7 {
    }
    public class Benchmark8 {
    }
    public class Benchmark9 {
    }
    public class Benchmark10 {
    }
    public class Benchmark11 {
    }
    public class Benchmark12 {
    }
    public class Benchmark13 {
    }
    public class Benchmark14 {
    }
    public class Benchmark15 {
    }
    public class Benchmark16 {
    }
    public class Benchmark17 {
    }
    public class Benchmark18 {
    }
    public class Benchmark19 {
    }
    public class Benchmark20 {
    }
    public class Benchmark21 {
    }
    public class Benchmark22 {
    }
    public class Benchmark23 {
    }
    public class Benchmark24 {
    }
    public class Benchmark25 {
    }
    public class Benchmark26 {
    }
    public class Benchmark27 {
    }
    public class Benchmark28 {
    }
    public class Benchmark29 {
    }
    public class Benchmark30 {
    }
    public class Benchmark31 {
    }
    public class Benchmark32 {
    }
    public class Benchmark33 {
    }
    public class Benchmark34 {
    }
    public class Benchmark35 {
    }
    public class Benchmark36 {
    }
    public class Benchmark37 {
    }
    public class Benchmark38 {
    }
    public class Benchmark39 {
    }
    public class Benchmark40 {
    }
    public class Benchmark41 {
    }
    public class Benchmark42 {
    }
    public class Benchmark43 {
    }
    public class Benchmark44 {
    }
    public class Benchmark45 {
    }
    public class Benchmark46 {
    }
    public class Benchmark47 {
    }
    public class Benchmark48 {
    }
    public class Benchmark49 {
    }
    public class Benchmark50 {
    }
    public class Benchmark51 {
    }
    public class Benchmark52 {
    }
    public class Benchmark53 {
    }
    public class Benchmark54 {
    }
    public class Benchmark55 {
    }
    public class Benchmark56 {
    }
    public class Benchmark57 {
    }
    public class Benchmark58 {
    }
    public class Benchmark59 {
    }
    public class Benchmark60 {
    }
    public class Benchmark61 {
    }
    public class Benchmark62 {
    }
    public class Benchmark63 {
    }
    public class Benchmark64 {
    }
    public class Benchmark65 {
    }
    public class Benchmark66 {
    }
    public class Benchmark67 {
    }
    public class Benchmark68 {
    }
    public class Benchmark69 {
    }
    public class Benchmark70 {
    }
    public class Benchmark71 {
    }
    public class Benchmark72 {
    }
    public class Benchmark73 {
    }
    public class Benchmark74 {
    }
    public class Benchmark75 {
    }
    public class Benchmark76 {
    }
    public class Benchmark77 {
    }
    public class Benchmark78 {
    }
    public class Benchmark79 {
    }
    public class Benchmark80 {
    }
    public class Benchmark81 {
    }
    public class Benchmark82 {
    }
    public class Benchmark83 {
    }
    public class Benchmark84 {
    }
    public class Benchmark85 {
    }
    public class Benchmark86 {
    }
    public class Benchmark87 {
    }
    public class Benchmark88 {
    }
    public class Benchmark89 {
    }
    public class Benchmark90 {
    }
    public class Benchmark91 {
    }
    public class Benchmark92 {
    }
    public class Benchmark93 {
    }
    public class Benchmark94 {
    }
    public class Benchmark95 {
    }
    public class Benchmark96 {
    }
    public class Benchmark97 {
    }
    public class Benchmark98 {
    }
    public class Benchmark99 {
    }
    public class Benchmark100 {
    }
    // #endregion
    // =================
}
