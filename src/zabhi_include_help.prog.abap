*&---------------------------------------------------------------------*
*& Include ZSNOW_RPT_HELP
*&---------------------------------------------------------------------*


DATA: LO_HTTP_CLIENT TYPE REF TO IF_HTTP_CLIENT,
      LV_URL         TYPE STRING,
      LV_JSON        TYPE STRING,
      LV_RESULT      TYPE STRING,
      LV_MESSAGE     TYPE NATXT,
      LV_RESPONSE    TYPE STRING,
      LV_MSGID       TYPE SY-MSGID,
      LV_MSGNO       TYPE SY-MSGNO,
      LV_CODE        TYPE I,
      LV_REASON      TYPE STRING,
      GT_DATA        TYPE ZZ_TABLE_TT.

TYPES: BEGIN OF TY_MESSAGE,
         ROLE    TYPE STRING,
         CONTENT TYPE STRING,
       END OF TY_MESSAGE.

TYPES: BEGIN OF TY_CHOICE,
         INDEX         TYPE I,
         MESSAGE       TYPE TY_MESSAGE,
         FINISH_REASON TYPE STRING,
       END OF TY_CHOICE.

TYPES: BEGIN OF TY_RESPONSE,
         ID      TYPE STRING,
         OBJECT  TYPE STRING,
         CHOICES TYPE STANDARD TABLE OF TY_CHOICE WITH EMPTY KEY,
       END OF TY_RESPONSE.

DATA:
  LV_LANG     TYPE CHAR2,
  LS_RESPONSE TYPE TY_RESPONSE.
TABLES ZABHI_AUTH.

SELECT SINGLE UNAME
  FROM ZABHI_AUTH
  INTO @DATA(LV_UNAME)
  WHERE UNAME EQ @SY-UNAME.
IF SY-SUBRC NE 0.
*  no authorization.
  MESSAGE I001(00) WITH 'No Authorization to -> Ask ABHI'.
  EXIT.
ENDIF.

IF SY-MSGTY <> SPACE.
  DATA(LV_V1) = SY-MSGV1.
  DATA(LV_V2) = SY-MSGV2.
  DATA(LV_V3) = SY-MSGV3.
  DATA(LV_V4) = SY-MSGV4.

  IF LV_V1 IS NOT INITIAL.
    LV_V1 = 'XXX'.
  ENDIF.
  IF LV_V2 IS NOT INITIAL.
    LV_V2 = 'YYY'.
  ENDIF.
  IF LV_V3 IS NOT INITIAL.
    LV_V3 = 'ZZZ'.
  ENDIF.
  IF LV_V4 IS NOT INITIAL.
    LV_V4 = 'XYZ'.
  ENDIF.
  CALL FUNCTION 'FORMAT_MESSAGE'
    EXPORTING
      ID        = SY-MSGID
*     LANG      = '-D'
      NO        = SY-MSGNO
      V1        = LV_V1 "SY-MSGV1
      V2        = LV_V2 "SY-MSGV2
      V3        = LV_V3 "SY-MSGV3
      V4        = LV_V4 "SY-MSGV4
    IMPORTING
      MSG       = LV_MESSAGE
    EXCEPTIONS
      NOT_FOUND = 1
      OTHERS    = 2.
  IF SY-SUBRC <> 0.
* Implement suitable error handling here
  ENDIF.
  LV_MSGID = SY-MSGID.
  LV_MSGNO = SY-MSGNO.

  SELECT *
    FROM TVARVC
    INTO TABLE @DATA(LT_TVARVC)
    WHERE NAME LIKE 'ABHI%'.
  IF SY-SUBRC NE 0.
    EXIT.
  ENDIF.

  DATA:
    LV_BODY   TYPE STRING,
    LV_STATUS TYPE I,
    LV_CLIENT_ID TYPE STRING,
    LV_CLIENT_SECRET TYPE STRING,
    LV_TOKEN  TYPE STRING,
    BEGIN OF LS_DATA,
      ACCESS_TOKEN TYPE STRING,
      UIURL TYPE STRING,
    END OF LS_DATA.

  READ TABLE LT_TVARVC INTO DATA(LS_TVARVC) WITH KEY NAME = 'ABHI_GET_TOKEN'.
  IF SY-SUBRC NE 0.
    EXIT.
  ELSE.
    LV_URL = LS_TVARVC-LOW.
  ENDIF.

  " 2️⃣ Create HTTP client for the token endpoint
  CALL METHOD CL_HTTP_CLIENT=>CREATE_BY_URL
    EXPORTING
      URL                = LV_URL
    IMPORTING
      CLIENT             = LO_HTTP_CLIENT
    EXCEPTIONS
      ARGUMENT_NOT_FOUND = 1
      PLUGIN_NOT_ACTIVE  = 2
      INTERNAL_ERROR     = 3
      OTHERS             = 4.

  IF SY-SUBRC <> 0.
    WRITE: / 'Error creating HTTP client'.
    EXIT.
  ENDIF.

  " 1️⃣ Prepare the request body (form-encoded)
  READ TABLE LT_TVARVC INTO LS_TVARVC WITH KEY NAME = 'ABHI_CLIENT_ID'.
  IF SY-SUBRC EQ 0.
    LV_CLIENT_ID = LS_TVARVC-LOW.
  ENDIF.
  READ TABLE LT_TVARVC INTO LS_TVARVC WITH KEY NAME = 'ABHI_CLIENT_SECRET'.
  IF SY-SUBRC EQ 0.
    LV_CLIENT_SECRET = LS_TVARVC-LOW.
  ENDIF.
  LV_BODY = |grant_type=client_credentials&client_id={ '&CLIENT_ID&' }&client_secret={ '&CLIENT_SECRET&' }|.
  REPLACE '&CLIENT_ID&'     IN LV_BODY WITH LV_CLIENT_ID.
  REPLACE '&CLIENT_SECRET&' IN LV_BODY WITH LV_CLIENT_SECRET.

  " 3️⃣ Set method and headers
  LO_HTTP_CLIENT->REQUEST->SET_METHOD( IF_HTTP_REQUEST=>CO_REQUEST_METHOD_POST ).
  LO_HTTP_CLIENT->REQUEST->SET_HEADER_FIELD( NAME = 'Content-Type' VALUE = 'application/x-www-form-urlencoded' ).
  LO_HTTP_CLIENT->REQUEST->SET_HEADER_FIELD( NAME = 'Accept'       VALUE = 'application/json' ).


  " 4️⃣ Set request body
  LO_HTTP_CLIENT->REQUEST->SET_CDATA( LV_BODY ).

  " 5️⃣ Send request
  CALL METHOD LO_HTTP_CLIENT->SEND
    EXCEPTIONS
      HTTP_COMMUNICATION_FAILURE = 1
      HTTP_INVALID_STATE         = 2
      HTTP_PROCESSING_FAILED     = 3.

  IF SY-SUBRC <> 0.
    WRITE: / 'Error sending request'.
    EXIT.
  ENDIF.

  " 6️⃣ Receive response
  CALL METHOD LO_HTTP_CLIENT->RECEIVE
    EXCEPTIONS
      HTTP_COMMUNICATION_FAILURE = 1
      HTTP_INVALID_STATE         = 2
      HTTP_PROCESSING_FAILED     = 3.

  IF SY-SUBRC <> 0.
    WRITE: / 'Error receiving response'.
  ENDIF.

  " 7️⃣ Get response

  CALL METHOD LO_HTTP_CLIENT->RESPONSE->GET_STATUS
    IMPORTING
      CODE   = LV_CODE
      REASON = LV_REASON.
  IF LV_CODE NE 200.
    MESSAGE I001(00) WITH 'Fetch Bearer Token failed, :'  LV_CODE LV_REASON.
    EXIT.
  ENDIF.

*lv_status   = lo_http_client->response->get_status( ).
  LV_RESPONSE = LO_HTTP_CLIENT->RESPONSE->GET_CDATA( ).


  " 8️⃣ Parse JSON response to extract access_token
  " Deserialize JSON into ABAP structure
  CALL METHOD /UI2/CL_JSON=>DESERIALIZE
    EXPORTING
      JSON = LV_RESPONSE
    CHANGING
      DATA = LS_DATA.
  LV_TOKEN = LS_DATA-ACCESS_TOKEN.


  " 9️⃣ Close connection
  CALL METHOD LO_HTTP_CLIENT->CLOSE( ).


*call API for logging
  READ TABLE LT_TVARVC INTO LS_TVARVC WITH KEY NAME = 'ABHI_LOGGING_URL'.
  IF SY-SUBRC NE 0.
    EXIT.
  ELSE.
    LV_URL = LS_TVARVC-LOW."'http://ask-abhi-uat-service.eba-pkqefsbr.us-east-1.elasticbeanstalk.com/api/error-log/analyze'.
  ENDIF.
  " Create HTTP client
  CALL METHOD CL_HTTP_CLIENT=>CREATE_BY_URL
    EXPORTING
      URL                = LV_URL
    IMPORTING
      CLIENT             = LO_HTTP_CLIENT
    EXCEPTIONS
      ARGUMENT_NOT_FOUND = 1
      PLUGIN_NOT_ACTIVE  = 2
      INTERNAL_ERROR     = 3
      OTHERS             = 4.

  " 2️⃣ Set request headers
  LO_HTTP_CLIENT->REQUEST->SET_HEADER_FIELD(
    NAME  = 'Authorization'
    VALUE = |Bearer { LV_TOKEN }| ).

  " Set HTTP headers

  LO_HTTP_CLIENT->REQUEST->SET_HEADER_FIELD( NAME = 'Content-Type'  VALUE = 'application/json' ).

  " Build JSON request
  LV_JSON = '{"username": "&1", "languageKey": "EN", "messageClass": "&msgid", "messageNumber": "&msgno", "messageText": "&2","messageDescription": "&2", "messageTextVariables": {"VAR1": "&v1", "VAR2": "&v2", "VAR3": "&v3", "VAR4": "&v4" }  }'.
  REPLACE '&1' IN LV_JSON WITH SY-UNAME.
  REPLACE '&2' IN LV_JSON WITH LV_MESSAGE.
  REPLACE '&msgid' IN LV_JSON WITH LV_MSGID.
  REPLACE '&msgno' IN LV_JSON WITH LV_MSGNO.
  WRITE SY-LANGU TO LV_LANG.
  REPLACE '&sprsl' IN LV_JSON WITH LV_LANG.
  REPLACE '&v1' IN LV_JSON WITH LV_V1.
  REPLACE '&v2' IN LV_JSON WITH LV_V2.
  REPLACE '&v3' IN LV_JSON WITH LV_V3.
  REPLACE '&v4' IN LV_JSON WITH LV_V4.

  LO_HTTP_CLIENT->REQUEST->SET_CDATA( LV_JSON ).

  LO_HTTP_CLIENT->REQUEST->SET_METHOD(
   EXPORTING
   METHOD = IF_HTTP_ENTITY=>CO_REQUEST_METHOD_POST ).

  " Send HTTP POST request
  CALL METHOD LO_HTTP_CLIENT->SEND
    EXCEPTIONS
      HTTP_COMMUNICATION_FAILURE = 1
      HTTP_INVALID_STATE         = 2
      HTTP_PROCESSING_FAILED     = 3
      OTHERS                     = 4.

  CALL METHOD LO_HTTP_CLIENT->RECEIVE
    EXCEPTIONS
      HTTP_COMMUNICATION_FAILURE = 1
      HTTP_INVALID_STATE         = 2
      HTTP_PROCESSING_FAILED     = 3
      OTHERS                     = 4.


  CALL METHOD LO_HTTP_CLIENT->RESPONSE->GET_STATUS
    IMPORTING
      CODE   = LV_CODE
      REASON = LV_REASON.

  IF LV_CODE EQ 200.

    MESSAGE I001(00) WITH 'Message reported to ABHI'." 'opening ABHI on browser...'.
  ELSE.
    MESSAGE I001(00) WITH 'Message report to ABHI failed, return code & reason:' LV_CODE LV_REASON.
    EXIT.
  ENDIF.
ENDIF.
DATA LV_URL2 TYPE CHAR300.
  LV_RESPONSE = LO_HTTP_CLIENT->RESPONSE->GET_CDATA( ).

  " 8️⃣ Parse JSON response to extract access_token
  " Deserialize JSON into ABAP structure
  CALL METHOD /UI2/CL_JSON=>DESERIALIZE
    EXPORTING
      JSON = LV_RESPONSE
    CHANGING
      DATA = LS_DATA.
  LV_URL2 = LS_DATA-UIURL.

*READ TABLE LT_TVARVC INTO LS_TVARVC WITH KEY NAME = 'ABHI_VIEWING_URL'.
*IF SY-SUBRC NE 0.
*  EXIT.
*ELSE.
**CONCATENATE 'http://ask-abhi-uat-ui.eba-pkqefsbr.us-east-1.elasticbeanstalk.com/' SY-UNAME '/' INTO LV_URL2.
*  CONCATENATE LS_TVARVC-LOW SY-UNAME '/' INTO LV_URL2.
*ENDIF.

CALL FUNCTION 'CALL_BROWSER'
  EXPORTING
    URL                    = LV_URL2
  EXCEPTIONS
    FRONTEND_NOT_SUPPORTED = 1
    FRONTEND_ERROR         = 2
    PROG_NOT_FOUND         = 3
    NO_BATCH               = 4
    UNSPECIFIED_ERROR      = 5
    OTHERS                 = 6.
IF SY-SUBRC <> 0.
  MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
          WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
ENDIF.
