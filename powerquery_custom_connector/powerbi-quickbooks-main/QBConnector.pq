section QBConnector;

client_id = "ABOp7jh27xVUS1rOFVQ3CmWx0sUuEI5vvOvERLIlh8tRV6rYAl";
client_secret = "zCZ6eTq8TVSB04gmuDdOkU1zmEjvePUMLqNjMqKJ";
required_scopes = "com.intuit.quickbooks.accounting	";


windowWidth = 600;
windowHeight = 800;


redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
base_url = "https://sandbox-quickbooks.api.intuit.com";
// Production : https://quickbooks.api.intuit.com

// TODO - Pagination -> No need.
// DONE - Refresh token -> Used the example
// DONE - Load into PowerBI -> MAKE SURE TO INCLUDE THE PUBLISH PROPERTY!!!
// DONE - TestConnection -> MAKE SURE TO PROVIDE THE DEFAULT VALUE FOR PATH
// DONE :( - Cannot auto refresh the source without a gateway


//
// Data Source definitionStartLogin

//
QBConnector = [
    TestConnection = (dataSourcePath) => {"QBConnector.Contents"},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ]
];


//
// OAuth2 flow definition
//
StartLogin = (resourceUrl, state, display) =>
    let
        plainTextCodeVerifier = Text.NewGuid() & Text.NewGuid(),
        bEnc = (s) => Text.Replace(Text.Replace(Text.BeforeDelimiter(Binary.ToText(s,BinaryEncoding.Base64),"="),"+","-"),"/","_"),
        codeVerifier = bEnc(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(plainTextCodeVerifier))),
        AuthorizeUrl = "https://appcenter.intuit.com/connect/oauth2?"
            & Uri.BuildQueryString(
                [
                    response_type = "code",
                    client_id = client_id,
                    scope = required_scopes,
                    state = state,
                    redirect_uri = redirect_uri,
                    code_challenge_method = "S256",
                    code_challenge = codeVerifier
                ]
            )
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = plainTextCodeVerifier
        ];

FinishLogin = (context, callbackUri, state) => 
    let 
        Parts = Uri.Parts(callbackUri)[Query]   
    in TokenMethod(Parts[code], "authorization_code", context);


TokenMethod = (code, grant_type, optional verifier) =>
    let
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grant_type = "authorization_code") then [code = code] else [refresh_token = code],
        query = 
            /* codeVerifier
            & codeParameter
            & */
             [
                grant_type = grant_type,
                code = code,
                redirect_uri = redirect_uri
            ],

        ManualHandlingStatusCodes = {},
        Response = Web.Contents(
            "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer?",
            [
                Content = Text.ToBinary(Uri.BuildQueryString(query)),
                Headers = [
                    #"Authorization" = "Basic " & Binary.ToText(Text.ToBinary(client_id & ":" & client_secret)),
                    #"Content-type" = "application/x-www-form-urlencoded", 
                    #"Accept" = "application/json"

                ],
                ManualStatusHandling = ManualHandlingStatusCodes
            ]
        ),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then
            error Error.Record(Parts[error], Parts[message]?)
        else
            Parts;

Refresh = (resourceUrl, refresh_token) => TokenMethod(refresh_token, "refresh_token");

//
// Exported functions
//
// These functions are exported to the M Engine (making them visible to end users), and associates
// them with the specified Data Source Kind. The Data Source Kind is used when determining which
// credentials to use during evaluation. 
//
// IMPORTANT - Credential matching is done based on the function's REQUIRED parameters.
// You can have as many different optional params, but the REQUIRED params must MATCH in every shared method.
//
// All data source functions associated to the same Data Source Kind must have a matching set of REQUIRED
// function parameters, including type, name, and the order in which they appear.



[DataSource.Kind = "QBConnector", Publish="QBConnector.UI"]
shared QBConnector.Contents = 
                                Value.ReplaceType(
                                    myQBConnector, 
                                    type function (
                                        tenantId as text,  
                                        query as (type text meta [
                                                                    Documentation.FieldCaption = "SQL Query",
                                                                    Documentation.SampleValues = {"Select * from Account"},
                                                                    Formatting.IsMultiLine = true,
                                                                    Formatting.IsCode = true
                                        ])
                                    ) as any);

myQBConnector = (tenantId as text,  query as text) =>
    let
        
        my_params =  [query = query],
        q_parameters = Uri.BuildQueryString(my_params),
        connectionsPath = base_url & "/v3/company/"& tenantId &"/query?" & q_parameters,
        defaultHeaders = [
                         #"Accept" = "application/json"
                         ],
        params = [],

        content = Web.Contents(connectionsPath, 
                                [Headers = defaultHeaders]
                                ),
        json = Json.Document(content),
  
        mydata = Record.FieldValues(json[QueryResponse]){0},
        ToTable = Table.FromList(mydata, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        FieldNames = Record.FieldNames(ToTable{0}[Column1]),
        FinalTable = Table.ExpandRecordColumn(ToTable,"Column1",FieldNames)
    in
        FinalTable;

//
// UI Export definition
//
QBConnector.UI = [
    Beta = true,
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")},
    SourceImage = QBConnector.Icons,
    SourceTypeImage = QBConnector.Icons
];

QBConnector.Icons = [
    Icon16 = {
        Extension.Contents("qb16.png"),
        Extension.Contents("qb20.png"),
        Extension.Contents("qb24.png"),
        Extension.Contents("qb32.png")
    },
    Icon32 = {
        Extension.Contents("qb32.png"),
        Extension.Contents("qb40.png"),
        Extension.Contents("qb48.png"),
        Extension.Contents("qb64.png")
    }
];


