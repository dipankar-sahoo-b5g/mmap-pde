System.debug('COUNT_ACCOUNTS: ' + [SELECT count() FROM Account]);
System.debug('COUNT_CONTACTS: ' + [SELECT count() FROM Contact]);
System.debug('COUNT_LICENSES: ' + [SELECT count() FROM Business_License__c]);
System.debug('COUNT_PATIENT_REGS: ' + [SELECT count() FROM Patient_Registration__c]);
System.debug('COUNT_STRAINS: ' + [SELECT count() FROM Strain__c]);
System.debug('COUNT_PLANT_BATCHES: ' + [SELECT count() FROM Plant_Batch__c]);
System.debug('COUNT_PACKAGES: ' + [SELECT count() FROM Product_Package__c]);
System.debug('COUNT_COAS: ' + [SELECT count() FROM Lab_Test_Result__c]);
System.debug('COUNT_TRANSACTIONS: ' + [SELECT count() FROM Dispense_Transaction__c]);

