Datetime startTime = Datetime.now();
Integer startCPU = Limits.getCpuTime();
for (Integer i = 1; i <= 1000; i++) {
    SObjectType objType = ((SObject) Type.forName('Account').newInstance()).getSObjectType();
}
Datetime endTime = Datetime.now();
Integer endCPU = Limits.getCpuTime();
System.debug('DI Registration Performance (Time): ' + (endTime.getTime() - startTime.getTime()));
System.debug('DI Registration Performance (CPU): ' + (endCPU - startCPU));

startTime = Datetime.now();
startCPU = Limits.getCpuTime();
for (Integer i = 1; i <= 1000; i++) {
    Schema.DescribeSObjectResult[] descResults = Schema.describeSObjects(new List<String>{ 'Account' });
    SObjectType objType = descResults[0].getSObjectType();
}
endTime = Datetime.now();
endCPU = Limits.getCpuTime();
System.debug('DI Resolution Performance (Time): ' + (endTime.getTime() - startTime.getTime()));
System.debug('DI Resolution Performance (CPU): ' + (endCPU - startCPU));

startTime = Datetime.now();
startCPU = Limits.getCpuTime();
for (Integer i = 1; i <= 1000; i++) {
    Schema.DescribeSObjectResult[] descResults = Schema.describeSObjects(new List<String>{ 'Account', 'Contact' });
    SObjectType objType = descResults[0].getSObjectType();
}
endTime = Datetime.now();
endCPU = Limits.getCpuTime();
System.debug('DI Resolution Performance (Time): ' + (endTime.getTime() - startTime.getTime()));
System.debug('DI Resolution Performance (CPU): ' + (endCPU - startCPU));
