section ZohoCRMConnector;

client_id = "1000.XPJMZ8WWNNA0309PXDZSJGQ0Z7O0OX";
client_secret = "4c78d2c1811f6cf6c000e9fc0597c5dba8c2250982";
required_scopes = "ZohoCRM.modules.ALL";


windowWidth = 600;
windowHeight = 800;


redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

// TODO - Pagination -> No need.
// DONE - Refresh token -> Used the example
// DONE - Load into PowerBI -> MAKE SURE TO INCLUDE THE PUBLISH PROPERTY!!!
// DONE - TestConnection -> MAKE SURE TO PROVIDE THE DEFAULT VALUE FOR PATH
// DONE :( - Cannot auto refresh the source without a gateway


//
// Data Source definitionStartLogin

//
ZohoCRMConnector = [
    TestConnection = (dataSourcePath) => {"ZohoCRMConnector.Contents"},
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
        AuthorizeUrl = "https://accounts.zoho.com/oauth/v2/auth?"
            & Uri.BuildQueryString(
                [
                    scope = required_scopes,                    
                    client_id = client_id,
                    redirect_uri = redirect_uri,
                    response_type = "code",
                    access_type = "online",
/*                  code_challenge_method = "S256",
                    code_challenge = codeVerifier, */
                    state = state 
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
        myUri = Text.Start(callbackUri,Text.Length(callbackUri)-1),
        Parts = Uri.Parts(myUri)[Query]   
    in TokenMethod(Parts[code], "authorization_code", context);


TokenMethod = (code, grant_type, optional verifier) =>
    let
        body = 
            /* codeVerifier
            & codeParameter
            & */
             [
                client_id = client_id,
                client_secret = client_secret,
                redirect_uri = redirect_uri,
                code = code,
                grant_type = grant_type

            ],

        ManualHandlingStatusCodes = {},
        Response = Web.Contents(
            "https://accounts.zoho.com/oauth/v2/token",

            [

                Headers = [
                    #"Content-type" = "application/x-www-form-urlencoded"
                ],

                Content = Text.ToBinary(Uri.BuildQueryString(body))
                ,ManualStatusHandling = ManualHandlingStatusCodes
                
            ]
        ),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then
            error Error.Record(Parts[error],code)
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



[DataSource.Kind = "ZohoCRMConnector", Publish="ZohoCRMConnector.UI"]
shared ZohoCRMConnector.Contents = 
                                Value.ReplaceType(
                                    myZohoCRMConnector, 
                                    type function (
                                        optional tenantId as text,  
                                        optional query as (type text meta [
                                                                    Documentation.FieldCaption = "SQL Query",
                                                                    Documentation.SampleValues = {"Select * from Account"},
                                                                    Formatting.IsMultiLine = true,
                                                                    Formatting.IsCode = true
                                        ])
                                    ) as any );

myZohoCRMConnector = (optional tenantId as text,  optional query as text) =>
    let
        credential = Extension.CurrentCredential(),
        my_params =  [query = query],
        q_parameters = Uri.BuildQueryString(my_params),
        connectionsPath = "https://www.zohoapis.com/crm/v2/Leads",
        defaultHeaders = [
                         #"Accept" = "application/json",
                         #"Authorization" = "Zoho-oauthtoken " & credential[access_token]
                         ],
        params = [],

        content = Web.Contents(connectionsPath, 
                                [Headers = defaultHeaders]),

        json = Json.Document(content)

    in
        json;

//
// UI Export definition
//
ZohoCRMConnector.UI = [
    Beta = true,
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")},
    SourceImage = ZohoCRMConnector.Icons,
    SourceTypeImage = ZohoCRMConnector.Icons
];

ZohoCRMConnector.Icons = [
    Icon16 = {
        Extension.Contents("zohocrm16.png"),
        Extension.Contents("zohocrm20.png"),
        Extension.Contents("zohocrm24.png"),
        Extension.Contents("zohocrm32.png")
    },
    Icon32 = {
        Extension.Contents("zohocrm32.png"),
        Extension.Contents("zohocrm40.png"),
        Extension.Contents("zohocrm48.png"),
        Extension.Contents("zohocrm64.png")
    }
];



