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
    public interface ITableLogger {
    }
    public interface IEmailLogger {
    }
    public interface IAWSS3Logger {
    }

    public class TableLogger implements ITableLogger, ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('Table: ' + message);
        }
    }

    public class EmailLogger implements IEmailLogger, ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('Email: ' + message);
        }
    }

    public class AWSS3Logger implements IAWSS3Logger, ILogger {
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
        private ILogger logger { get; set; }
        private GlobalConfiguration configuration { get; set; }

        public AccountService() {
        }

        public AccountService(ILogger logger, GlobalConfiguration confiragion) {
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
            .addSingletonFactory('DITest.ITableLogger', 'DITest.LoggerFactory<DITest.TableLogger>')
            .addSingletonFactory('DITest.IEmailLogger', 'DITest.LoggerFactory<DITest.EmailLogger>')
            .addSingletonFactory('DITest.IAWSS3Logger', 'DITest.LoggerFactory<DITest.AWSS3Logger>')
            .buildServiceProvider();

        ILogger tableLogger = (ILogger) provider.getService('DITest.ITableLogger');
        ILogger emailLogger = (ILogger) provider.getService('DITest.IEmailLogger');
        ILogger awss3Logger = (ILogger) provider.getService('DITest.IAWSS3Logger');
        ILogger nullLogger = (ILogger) provider.getService('DITest.ILogger');

        Assert.isTrue(tableLogger instanceof TableLogger);
        Assert.isTrue(emailLogger instanceof EmailLogger);
        Assert.isTrue(awss3Logger instanceof AWSS3Logger);
        Assert.isTrue(nullLogger instanceof NullLogger);
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

    // ! Comment out before release, so no dependencies to standard SObjects such as Account and Contact!
    // TODO: Comment out before release, so no dependencies to standard SObjects such as Account and Contact!
    // @IsTest
    // static void test_factories_generic_services_sobjects() {
    //     DI.ServiceProvider provider = DI.services()
    //         .addSingletonFactory('DITest.IRepository', 'DITest.RepositoryFactory<DITest.Repository>')
    //         .BuildServiceProvider();

    //     Repository repository = (Repository) provider.getService('DITest.IRepository<Account, Contact>');
    //     Assert.areEqual(2, repository.sobjectTypes.size());
    //     Assert.areEqual(Account.SObjectType, repository.sobjectTypes[0]);
    //     Assert.areEqual(Contact.SObjectType, repository.sobjectTypes[1]);
    //     throw new NoSuchElementException('Comment out before release!');
    // }

    public class GlobalConfiguration {
    }

    public class AccountServiceFactory implements DI.ServiceFactory {
        public IAccountService newInstance(Type serviceType, DI.ServiceProvider provider) {
            return new AccountService(
                (ILogger) provider.getService(ILogger.class),
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
        public ILogger newInstance(Type servcieType, List<String> genericTypes, DI.ServiceProvider provider) {
            return new Logger((IWriter) provider.getService(genericTypes[0]));
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
        public IRepository newInstance(Type servcieType, List<String> genericTypes, DI.ServiceProvider provider) {
            List<SObjectType> sobjectTypes = new List<SObjectType>();
            for (String typeName : genericTypes) {
                sobjectTypes.add(((SObject) Type.forName(typeName).newInstance()).getSObjectType());
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
            services.addTransient('DITest.ILogger', 'DITest.EmailLogger');
        }
    }

    public class Module4 extends DI.Module {
        public override void configure(DI.ServiceCollection services) {
        }
    }

    public class Module5 extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
        }
    }

    @IsTest
    static void test_modules_dependency() {
        DI.Module module1 = DI.getModule(Module1.class);
        ILogger logger1 = (ILogger) module1.getService(ILogger.class);
        Assert.isTrue(logger1 instanceof TableLogger);

        DI.Module module3 = DI.getModule(Module3.class);
        ILogger logger3 = (ILogger) module3.getService(ILogger.class);
        Assert.isTrue(logger3 instanceof EmailLogger);
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

    public interface IWrongFactory {
    }

    public class WrongFactory {
        // will give error during service resolving, because it is not factory class.
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
                String noName = null;
                provider.getService(noName);
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

        Assert.areEqual(1, DI.ROOT_MODULE.services.getDescriptors().size());
    }

    @IsTest
    static void test_exceptions() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.GlobalConfiguration', new GlobalConfiguration())
            .addSingletonFactory('DITest.IWrongFactory', 'DITest.WrongFactory')
            .addSingletonFactory('DITest.ILogger', 'DITest.NullExceptionLoggerFactory')
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
            String noName = null;
            provider.getService(noName);
        } catch (DI.DIIllegalArgumentException ex) {
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
    // #endregion
    // =================
}
