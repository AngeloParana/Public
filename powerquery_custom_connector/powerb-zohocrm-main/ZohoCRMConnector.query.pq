// This is where you can write sample queries to test your extension.
let 
    source = ZohoCRMConnector.Contents(),
    org = source{0}[tenantId],
    Contacts = ZohoCRMConnector.Contents("https://api.xero.com/api.xro/2.0/Contacts", org),
    Conts = List.Count(Contacts[Contacts])
     in Conts
