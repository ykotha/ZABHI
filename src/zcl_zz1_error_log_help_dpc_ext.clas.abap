class ZCL_ZZ1_ERROR_LOG_HELP_DPC_EXT definition
  public
  inheriting from ZCL_ZZ1_ERROR_LOG_HELP_DPC
  create public .

public section.

  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_ENTITY
    redefinition .
protected section.

  methods ERROR_LOGSET_GET_ENTITY
    redefinition .
  methods ERROR_LOGSET_GET_ENTITYSET
    redefinition .
  methods ERROR_LOGSET_CREATE_ENTITY
    redefinition .
private section.

  methods ADD_TO_CHAT_CONVERATION
    importing
      !I_UUID type SYSUUID_C22
      !LS_CONVERSATION type ZCHAT_CONV
    returning
      value(RESULT) type SUBRC .
  methods READ_CHAT_CONVERSTAION
    importing
      !I_UUID type SYSUUID_C22
    returning
      value(HISTORY) type ZTT_CHAT_CONV .
  methods GET_UUID22
    returning
      value(R_UUID) type SYSUUID_C22 .
  methods READ_LAST_ERROR
    exporting
      value(LAST_ERROR_MSG) type STRING
      value(ERRORTYPE) type STRING .
ENDCLASS.



CLASS ZCL_ZZ1_ERROR_LOG_HELP_DPC_EXT IMPLEMENTATION.


  method /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_ENTITY.
**TRY.
*CALL METHOD SUPER->/IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_ENTITY
*  EXPORTING
**    IV_ENTITY_NAME          =
**    IV_ENTITY_SET_NAME      =
**    IV_SOURCE_NAME          =
*    IO_DATA_PROVIDER        =
**    IT_KEY_TAB              =
**    IT_NAVIGATION_PATH      =
**    IO_TECH_REQUEST_CONTEXT =
**  IMPORTING
**    ER_ENTITY               =
*    .
**  CATCH /IWBEP/CX_MGW_BUSI_EXCEPTION.
**  CATCH /IWBEP/CX_MGW_TECH_EXCEPTION.
**ENDTRY.

  DATA: lt_key_tab   TYPE /iwbep/t_mgw_name_value_pair,
        lv_entity_id TYPE string,
        ls_data      TYPE ZCL_ZZ1_ERROR_LOG_HELP_MPC=>TS_ERROR_LOG.
DATA LV_LANG TYPE CHAR2.
  TRY.
      " Extract the key from the request
*      io_tech_request_context->get_converted_keys(
*        IMPORTING
*          es_key_values = lt_key_tab
*      ).
*
*      " Retrieve the entity key (example: ID)
*      READ TABLE lt_key_tab INTO DATA(ls_key) WITH KEY name = 'ID'.
*      IF sy-subrc = 0.
*        lv_entity_id = ls_key-value.
*      ELSE.
*        RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception
*          EXPORTING
*            textid = /iwbep/cx_mgw_tech_exception=>update_failed.
*      ENDIF.

      " Map the incoming data to the entity structure
      io_data_provider->read_entry_data(
        IMPORTING
          es_data = ls_data
      ).

      " Perform the update logic (example: update database table)
*      MODIFY your_database_table FROM ls_data
*        WHERE id = lv_entity_id.
*      IF sy-subrc <> 0.
*        RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception
*          EXPORTING
*            textid = /iwbep/cx_mgw_tech_exception=>update_failed.
*      ENDIF.


DATA: LO_HTTP_CLIENT TYPE REF TO IF_HTTP_CLIENT,
      LV_URL         TYPE STRING,
      LV_JSON        TYPE STRING,
      LV_RESULT      TYPE STRING,
      LV_MESSAGE     TYPE NATXT,
      LV_RESPONSE    TYPE STRING,
      LV_CODE        TYPE I,
      LV_REASON      TYPE STRING.

lv_url = 'https://www.ask-abhi.34.160.35.150.nip.io/api/error-log/analyze'.

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

  " Set HTTP headers

  LO_HTTP_CLIENT->REQUEST->SET_HEADER_FIELD( NAME = 'Content-Type'  VALUE = 'application/json' ).

  " Build JSON request
  LV_JSON = '{"username": "&1", "errors": [ { "msgid": "&msgid", "msgno": "&msgno", "sprsl": "&sprsl", "errortext": "&2" } ] }'.
  REPLACE '&1' IN LV_JSON WITH SY-UNAME.
  REPLACE '&2' IN LV_JSON WITH ls_data-ERRORTEXT.
  replace '&msgid' in lv_json with ls_data-MSGID.
  replace '&msgno' in lv_json with ls_data-MSGno.
  write sy-langu to lv_lang.
  replace '&sprsl' in lv_json with lv_lang.

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

    MESSAGE I001(00) WITH 'Message reported to ABHI successfully,' 'opening ABHI on browser...'.
  ELSE.
    MESSAGE I001(00) WITH 'Message report to ABHI failed, return code & reason:' LV_CODE LV_REASON.
  ENDIF.

LS_DATA-RESPONSE = LV_REASON.

      " Return the updated entity
      copy_data_to_ref(
        EXPORTING
          is_data = ls_data
        CHANGING
          cr_data = er_entity
      ).

    CATCH /iwbep/cx_mgw_tech_exception INTO DATA(lo_exception).
      RAISE EXCEPTION lo_exception.
  ENDTRY.
  endmethod.


  method ADD_TO_CHAT_CONVERATION.
    modify ZCHAT_CONV from LS_CONVERSATION.
    result = sy-subrc.
    commit work and wait.
  endmethod.


  method ERROR_LOGSET_CREATE_ENTITY.
**TRY.
*CALL METHOD SUPER->ERROR_LOGSET_CREATE_ENTITY
*  EXPORTING
*    IV_ENTITY_NAME          = IV_ENTITY_NAME
*    IV_ENTITY_SET_NAME      = IV_ENTITY_SET_NAME
*    IV_SOURCE_NAME          = IV_SOURCE_NAME
*    IT_KEY_TAB              = IT_KEY_TAB
**    IO_TECH_REQUEST_CONTEXT =
*    IT_NAVIGATION_PATH      = IT_NAVIGATION_PATH
**    IO_DATA_PROVIDER        =
**  IMPORTING
**    ER_ENTITY               =
*    .
**  CATCH /IWBEP/CX_MGW_BUSI_EXCEPTION.
**  CATCH /IWBEP/CX_MGW_TECH_EXCEPTION.
**ENDTRY.
    BREAK-POINT.
    er_entity-MSGID = '123'.

  endmethod.


  METHOD ERROR_LOGSET_GET_ENTITY.

    TYPES:
      BEGIN OF TY_MESSAGE,
        ROLE    TYPE STRING,
        CONTENT TYPE STRING,
      END OF TY_MESSAGE.
    TYPES TT_MESSAGES TYPE STANDARD TABLE OF TY_MESSAGE WITH DEFAULT KEY.
    TYPES:
      BEGIN OF TY_REQUEST_MESSAGE,
        MODEL    TYPE CHAR40,
        MESSAGES TYPE TT_MESSAGES,
      END OF TY_REQUEST_MESSAGE.

    TYPES:
      BEGIN OF TY_CHOICE,
        INDEX         TYPE I,
        MESSAGE       TYPE TY_MESSAGE,
        FINISH_REASON TYPE STRING,
      END OF TY_CHOICE.

    TYPES:
      BEGIN OF TY_RESPONSE,
        ID      TYPE STRING,
        OBJECT  TYPE STRING,
        CHOICES TYPE STANDARD TABLE OF TY_CHOICE WITH EMPTY KEY,
      END OF TY_RESPONSE.
    FIELD-SYMBOLS <LT_DATA> TYPE TABLE.

    DATA :
      LV_COUNT       TYPE NUMC4,
      LS_KEY_TAB     TYPE LINE OF /IWBEP/T_MGW_NAME_VALUE_PAIR,
      LO_HTTP_CLIENT TYPE REF TO IF_HTTP_CLIENT,
      LV_URL         TYPE STRING,
      LV_JSON        TYPE STRING,
      LV_RESULT      TYPE STRING,
      LV_MESSAGE     TYPE NATXT,
      LS_MESSAGE     TYPE TY_MESSAGE,
      LV_RESPONSE    TYPE STRING,
      GT_DATA        TYPE ZZ_TABLE_TT,
      LS_RESPONSE    TYPE TY_RESPONSE,
      LS_DATA        TYPE REF TO DATA.

    DATA:
      LV_UUIDC22          TYPE SYSUUID_C22,
      LT_ERR_TABLE        TYPE /IWFND/SUTIL_LOG_RESULT_T,
      LS_ERR_LOG          TYPE /IWFND/SUTIL_LOG_RESULT,
      MT_IWFND_RESULT     TYPE /IWFND/SUTIL_LOG_RESULT_T,
      MV_IWFND_ERROR_TEXT TYPE STRING,
      MO_SUTIL_MONI       TYPE REF TO /IWFND/IF_MONITORING,
      T_SLG1_MESSAGES     TYPE STANDARD TABLE OF BALM,
      T_SLG1_HEADER       TYPE STANDARD TABLE OF BALHDR,
      T_CONTEXTS          TYPE STANDARD TABLE OF BALC,
      LV_TIME_FROM        TYPE SY-UZEIT,
      LO_REQUEST_CONTEXT  TYPE REF TO /IWBEP/IF_MGW_REQ_ENTITY,
      LV_CUSTOM_HEADER    TYPE STRING,
      LS_REQ_MESSAGES     TYPE TY_REQUEST_MESSAGE..

    " Get the request context
    LO_REQUEST_CONTEXT = IO_TECH_REQUEST_CONTEXT.

    " Get the custom header value
    DATA(LT_HEADERS) = LO_REQUEST_CONTEXT->GET_REQUEST_HEADERS( ).

    READ TABLE LT_HEADERS INTO DATA(LS_HEADER) WITH KEY NAME = 'uuidc22'.
    LV_UUIDC22 = LS_HEADER-VALUE.


    "read the importing parameter
    READ TABLE IT_KEY_TAB INTO LS_KEY_TAB WITH KEY NAME = 'Line' .
    IF LS_KEY_TAB-VALUE IS NOT INITIAL.
      ER_ENTITY-LINE = LS_KEY_TAB-VALUE.
    ENDIF.


    READ TABLE IT_KEY_TAB INTO LS_KEY_TAB WITH KEY NAME = 'Query' .
    IF LS_KEY_TAB-VALUE IS NOT INITIAL.
      ER_ENTITY-QUERY = LS_KEY_TAB-VALUE.
      IF ER_ENTITY-LINE = '1'.
        CLEAR ER_ENTITY-QUERY. " consider user error log
      ENDIF.
    ENDIF.

*   VALIDATION
    IF ER_ENTITY-LINE EQ '2' AND ER_ENTITY-QUERY IS INITIAL.
      ER_ENTITY-RESPONSE = 'LINE 2 = User Query, query input cannot be blank for line option 2'.

    ELSEIF ER_ENTITY-LINE NE  '0' AND ER_ENTITY-LINE NE '2'.
      ME->READ_LAST_ERROR(
        IMPORTING
          LAST_ERROR_MSG =   ER_ENTITY-QUERY
          ERRORTYPE      =   ER_ENTITY-ERRORTYPE ).


    ENDIF.

    IF ER_ENTITY-QUERY IS INITIAL.
      LV_MESSAGE = 'SAP Error - Material 1234 is not defined for sales org.1710,  distr.chan.10, language EN'.
    ELSE.
      CONCATENATE 'SAP Error' ER_ENTITY-QUERY INTO LV_MESSAGE SEPARATED BY SPACE.
    ENDIF.
    LV_URL = 'https://api.openai.com/v1/chat/completions'.


    IF ER_ENTITY-LINE EQ '0'.
      ER_ENTITY-RESPONSE = 'LINE 0 = Response for Test run, No query is considered/sent to AI '.
    ELSEIF ER_ENTITY-LINE EQ '2' AND ER_ENTITY-QUERY IS INITIAL.
      ER_ENTITY-RESPONSE = 'LINE 2 =Query cannot be blank for line option 2'.
    ELSEIF  ER_ENTITY-LINE = '0' AND ER_ENTITY-QUERY IS INITIAL.
      ER_ENTITY-RESPONSE = 'LINE # 0/2 = No error log found in system to process'.
    ELSEIF ER_ENTITY-LINE EQ '1' OR ER_ENTITY-LINE EQ '2'.
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

      " Set HTTP headers
      LO_HTTP_CLIENT->REQUEST->SET_HEADER_FIELD( NAME = 'Authorization' VALUE = 'Bearer <>' ).
      LO_HTTP_CLIENT->REQUEST->SET_HEADER_FIELD( NAME = 'Content-Type'  VALUE = 'application/json' ).
      DATA LV_CHAR22 TYPE STRING.
      IF LV_UUIDC22 IS INITIAL.
        LV_UUIDC22 = ME->GET_UUID22( ).
      ELSE.
        DATA(LT_PREV_MESSAGES) = ME->READ_CHAT_CONVERSTAION( I_UUID = LV_UUIDC22 ).
      ENDIF.

      " Build JSON request

      LS_REQ_MESSAGES-MODEL = 'gpt-4'.
      IF LT_PREV_MESSAGES IS NOT INITIAL.
        LOOP AT LT_PREV_MESSAGES INTO DATA(LS_PREV_MESSAGE).
          LV_COUNT = LS_PREV_MESSAGE-CNT1.
          LS_MESSAGE-ROLE = LS_PREV_MESSAGE-ROLE.
          LS_MESSAGE-CONTENT = LS_PREV_MESSAGE-CONTENT.
          APPEND LS_MESSAGE TO LS_REQ_MESSAGES-MESSAGES.
        ENDLOOP.
      ENDIF.

      CLEAR LS_PREV_MESSAGE.
      MOVE-CORRESPONDING LS_MESSAGE TO LS_PREV_MESSAGE.
      ADD 1 TO LV_COUNT.
      LS_PREV_MESSAGE-KEY1 = LV_UUIDC22.
      LS_PREV_MESSAGE-CNT1 = LV_COUNT.
      LS_PREV_MESSAGE-ROLE = LS_MESSAGE-ROLE = 'user'.
      LS_PREV_MESSAGE-CONTENT = LS_MESSAGE-CONTENT = |{ LV_MESSAGE }|.
      APPEND LS_MESSAGE TO LS_REQ_MESSAGES-MESSAGES.
      ME->ADD_TO_CHAT_CONVERATION(
        EXPORTING
          I_UUID          =  LV_UUIDC22                " 16 Byte UUID in 22 Characters (Usually Base64 Encoded)
          LS_CONVERSATION =  LS_PREV_MESSAGE  ).

      LV_JSON = /UI2/CL_JSON=>SERIALIZE( EXPORTING DATA   = LS_REQ_MESSAGES PRETTY_NAME = /UI2/CL_JSON=>PRETTY_MODE-LOW_CASE ).
*      LV_JSON = '{   "model": "gpt-4-turbo",  "messages": [     { "role": "user", "content": "SAP Error - &P_Q&" }  ]}'.
*lv_message = 'Material is not defined for sales org.,  distr.chan.,  SAP'.
*      REPLACE '&P_Q&' WITH LV_MESSAGE INTO LV_JSON.

      LO_HTTP_CLIENT->REQUEST->SET_CDATA( LV_JSON ).

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

      " Get the response body
      LV_RESPONSE = LO_HTTP_CLIENT->RESPONSE->GET_CDATA( ).

      CALL METHOD /UI2/CL_JSON=>DESERIALIZE
        EXPORTING
          JSON = LV_RESPONSE
        CHANGING
          DATA = LS_RESPONSE.
      data ls_resp_header type ihttpnvp.
      ls_resp_header-name = 'uuidc22'.
      ls_resp_header-value = LV_UUIDC22.
*      LV_CHAR22 =  LV_UUIDC22.
      SET_HEADER( is_header = ls_resp_header ).

      LOOP AT LS_RESPONSE-CHOICES INTO DATA(LS_CHOICE).
        CONCATENATE ER_ENTITY-RESPONSE  LS_CHOICE-MESSAGE-CONTENT INTO ER_ENTITY-RESPONSE.
        CLEAR LS_PREV_MESSAGE.
        MOVE-CORRESPONDING LS_CHOICE-MESSAGE TO LS_PREV_MESSAGE.
        ADD 1 TO LV_COUNT.
        LS_PREV_MESSAGE-KEY1 = LV_UUIDC22.
        LS_PREV_MESSAGE-CNT1 = LV_COUNT.
        LS_PREV_MESSAGE-ROLE = LS_CHOICE-MESSAGE-ROLE.
        LS_PREV_MESSAGE-CONTENT = LS_CHOICE-MESSAGE-CONTENT.
        ME->ADD_TO_CHAT_CONVERATION(
          EXPORTING
            I_UUID          =  LV_UUIDC22                " 16 Byte UUID in 22 Characters (Usually Base64 Encoded)
            LS_CONVERSATION =  LS_PREV_MESSAGE  ).
      ENDLOOP.
      IF LS_RESPONSE IS INITIAL.
        ER_ENTITY-RESPONSE = LV_RESPONSE.
        ER_ENTITY-ERRORTYPE = 'ERROR'.
      ENDIF.

    ELSE.
      ER_ENTITY-RESPONSE = 'ONLY line 0(TESTRUN NO AI CALL),2(AI),3(CUSTOMER QUERY) are considered, other line # will return back latest error query'.
    ENDIF.
  ENDMETHOD.


  METHOD ERROR_LOGSET_GET_ENTITYSET.
**TRY.
*CALL METHOD SUPER->ERROR_LOGSET_GET_ENTITYSET
*  EXPORTING
*    IV_ENTITY_NAME           =
*    IV_ENTITY_SET_NAME       =
*    IV_SOURCE_NAME           =
*    IT_FILTER_SELECT_OPTIONS =
*    IS_PAGING                =
*    IT_KEY_TAB               =
*    IT_NAVIGATION_PATH       =
*    IT_ORDER                 =
*    IV_FILTER_STRING         =
*    IV_SEARCH_STRING         =
**    IO_TECH_REQUEST_CONTEXT  =
**  IMPORTING
**    ET_ENTITYSET             =
**    ES_RESPONSE_CONTEXT      =
*    .
**  CATCH /IWBEP/CX_MGW_BUSI_EXCEPTION.
**  CATCH /IWBEP/CX_MGW_TECH_EXCEPTION.
**ENDTRY.
    DATA : LS_KEY_TAB TYPE LINE OF /IWBEP/T_MGW_NAME_VALUE_PAIR.

    DATA: LO_HTTP_CLIENT TYPE REF TO IF_HTTP_CLIENT,
          LV_URL         TYPE STRING,
          LV_JSON        TYPE STRING,
          LV_RESULT      TYPE STRING,
          LV_MESSAGE     TYPE NATXT,
          LV_RESPONSE    TYPE STRING,
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
      LV_SERVICE        TYPE STRING , "VALUE 'MM_PUR_PO_MAINT_V2_SRV',
      LV_CONTEXT_STRING TYPE STRING,
      LS_RESPONSE       TYPE TY_RESPONSE.

    DATA: T_SLG1_MESSAGES TYPE STANDARD TABLE OF BALM,
          T_SLG1_HEADER   TYPE STANDARD TABLE OF BALHDR,
          T_CONTEXTS      TYPE STANDARD TABLE OF BALC,
          LS_S_LOG        TYPE BAL_S_LOG,
          LV_TIME_FROM    TYPE SY-UZEIT.



    "read the importing parameter
    READ TABLE IT_FILTER_SELECT_OPTIONS INTO DATA(LS_FILTER_SELECT_OPTIONS) WITH KEY PROPERTY = 'service' .

    IF SY-SUBRC EQ 0.
      READ TABLE LS_FILTER_SELECT_OPTIONS-SELECT_OPTIONS INTO DATA(LR_RANGE) INDEX 1 .
      IF SY-SUBRC EQ 0.
        LV_SERVICE = LR_RANGE-LOW.
      ENDIF.
    ENDIF.

* SLG1 application log read
    LV_TIME_FROM = SY-UZEIT - '001000'.
    CALL FUNCTION 'APPL_LOG_READ_DB'
      EXPORTING
*       OBJECT          = '*'
*       SUBOBJECT       = '*'
*       EXTERNAL_NUMBER = ' '
        DATE_FROM       = SY-DATUM
        DATE_TO         = SY-DATUM
        TIME_FROM       = LV_TIME_FROM
        TIME_TO         = SY-UZEIT
*       LOG_CLASS       = '4'
*       PROGRAM_NAME    = '*'
*       TRANSACTION_CODE         = '*'
        USER_ID         = SY-UNAME
*       MODE            = '+'
        PUT_INTO_MEMORY = 'X'
* IMPORTING
*       NUMBER_OF_LOGS  =
      TABLES
        HEADER_DATA     = T_SLG1_HEADER
*       HEADER_PARAMETERS        =
        MESSAGES        = T_SLG1_MESSAGES
*       MESSAGE_PARAMETERS       =
        CONTEXTS        = T_CONTEXTS
*       T_EXCEPTIONS    =
      .
    LOOP AT T_SLG1_HEADER INTO DATA(LS_SLG1_HEADER) WHERE EXTNUMBER EQ 'No request ID has been provided'.
      DELETE T_SLG1_MESSAGES WHERE LOGNUMBER EQ LS_SLG1_HEADER-LOGNUMBER.

    ENDLOOP.
    DELETE T_SLG1_HEADER WHERE EXTNUMBER EQ 'No request ID has been provided'.
    DELETE T_SLG1_MESSAGES WHERE MSGTY NE 'E' AND MSGTY NE 'A'.
    IF LV_SERVICE IS NOT INITIAL.
      LOOP AT T_SLG1_HEADER INTO LS_SLG1_HEADER.
        CALL FUNCTION 'BAL_LOG_HDR_READ'
          EXPORTING
            I_LOG_HANDLE  = LS_SLG1_HEADER-LOG_HANDLE
            I_LANGU       = SY-LANGU
          IMPORTING
            E_S_LOG       = LS_S_LOG
*           E_EXISTS_ON_DB                 =
*           E_CREATED_IN_CLIENT            =
*           E_SAVED_IN_CLIENT              =
*           E_IS_MODIFIED =
*           E_LOGNUMBER   =
*           E_STATISTICS  =
*           E_EPP_DATA    =
*           E_TXT_OBJECT  =
*           E_TXT_SUBOBJECT                =
*           E_TXT_ALTCODE =
*           E_TXT_ALMODE  =
*           E_TXT_ALSTATE =
*           E_TXT_PROBCLASS                =
*           E_TXT_DEL_BEFORE               =
*           E_WARNING_TEXT_NOT_FOUND       =
          EXCEPTIONS
            LOG_NOT_FOUND = 1
            OTHERS        = 2.
        IF SY-SUBRC <> 0.
* Implement suitable error handling here

        ENDIF.
        IF LS_S_LOG-CONTEXT-VALUE CS LV_SERVICE.
        ELSE.
          DELETE T_SLG1_MESSAGES WHERE LOGNUMBER = LS_SLG1_HEADER-LOGNUMBER.
        ENDIF.
      ENDLOOP.
    ENDIF.
    SORT T_SLG1_MESSAGES BY LOGNUMBER DESCENDING MSGV1 DESCENDING MSGV2 DESCENDING MSGV3 DESCENDING MSGV4 DESCENDING.
    DELETE ADJACENT DUPLICATES FROM T_SLG1_MESSAGES.
    DATA: LS_CONTEXT   TYPE BALC, LT_RAW_INPUT TYPE TABLE OF BALCONVALR.



    DATA LS_ENTITY LIKE LINE OF ET_ENTITYSET.

    LOOP AT T_SLG1_MESSAGES INTO DATA(LS_SLG1_MESSAGE).
      MOVE-CORRESPONDING LS_SLG1_MESSAGE TO    LS_ENTITY.

      CALL FUNCTION 'FORMAT_MESSAGE'
        EXPORTING
          ID        = LS_SLG1_MESSAGE-MSGID
*         LANG      = '-D'
          NO        = LS_SLG1_MESSAGE-MSGNO
          V1        = LS_SLG1_MESSAGE-MSGV1
          V2        = LS_SLG1_MESSAGE-MSGV2
          V3        = LS_SLG1_MESSAGE-MSGV3
          V4        = LS_SLG1_MESSAGE-MSGV4
        IMPORTING
          MSG       = LS_ENTITY-ERRORTEXT
        EXCEPTIONS
          NOT_FOUND = 1
          OTHERS    = 2.
      IF SY-SUBRC <> 0.
* Implement suitable error handling here
      ENDIF.

      APPEND LS_ENTITY TO ET_ENTITYSET.

    ENDLOOP.

  ENDMETHOD.


  METHOD GET_UUID22.
    DATA(SYSTEM_UUID) = CL_UUID_FACTORY=>CREATE_SYSTEM_UUID( ).
    TRY.
        DATA(UUID_X16) = SYSTEM_UUID->CREATE_UUID_X16( ).
        SYSTEM_UUID->CONVERT_UUID_X16( EXPORTING
                                         UUID = UUID_X16
                                       IMPORTING
                                         UUID_C22 = R_UUID
                                         UUID_C26 = DATA(UUID_C26)
                                         UUID_C32 = DATA(UUID_C32) ).
      CATCH CX_UUID_ERROR.

    ENDTRY.
  ENDMETHOD.


  METHOD READ_CHAT_CONVERSTAION.
    SELECT * FROM ZCHAT_CONV INTO TABLE HISTORY WHERE KEY1 = I_UUID.
  ENDMETHOD.


  METHOD READ_LAST_ERROR.
    DATA:
      LV_TIME_FROM        TYPE SY-UZEIT,
      MT_IWFND_RESULT     TYPE /IWFND/SUTIL_LOG_RESULT_T,
      MV_IWFND_ERROR_TEXT TYPE STRING,
      T_SLG1_MESSAGES     TYPE STANDARD TABLE OF BALM,
      T_SLG1_HEADER       TYPE STANDARD TABLE OF BALHDR,
      T_CONTEXTS          TYPE STANDARD TABLE OF BALC,
      MO_SUTIL_MONI       TYPE REF TO /IWFND/IF_MONITORING.

    MO_SUTIL_MONI = /IWFND/CL_MONITORING_FACT=>GET_INSTANCE( ).
* iwfnd/error_log read
    MO_SUTIL_MONI->ERROR_LOG_GET_RESULT(
     EXPORTING
       IV_USERNAME          = SY-UNAME
     IMPORTING
       ET_RESULT            = MT_IWFND_RESULT
       EV_ERROR_TEXT        = MV_IWFND_ERROR_TEXT ).
    SORT MT_IWFND_RESULT BY TIMESTAMP DESCENDING.

* SLG1 application log read
    LV_TIME_FROM = SY-UZEIT - '001000'.
    CALL FUNCTION 'APPL_LOG_READ_DB'
      EXPORTING
        DATE_FROM   = SY-DATUM
        DATE_TO     = SY-DATUM
        TIME_FROM   = LV_TIME_FROM
        TIME_TO     = SY-UZEIT
        USER_ID     = SY-UNAME
      TABLES
        HEADER_DATA = T_SLG1_HEADER
        MESSAGES    = T_SLG1_MESSAGES
        CONTEXTS    = T_CONTEXTS.

    LOOP AT T_SLG1_HEADER INTO DATA(LS_SLG1_HEADER)
      WHERE EXTNUMBER EQ 'No request ID has been provided'.
      DELETE T_SLG1_MESSAGES WHERE LOGNUMBER EQ LS_SLG1_HEADER-LOGNUMBER.
    ENDLOOP.
    DELETE T_SLG1_MESSAGES WHERE MSGTY NE 'E' AND MSGTY NE 'A'.
    SORT T_SLG1_MESSAGES BY LOGNUMBER DESCENDING MSGV1
    DESCENDING MSGV2 DESCENDING MSGV3 DESCENDING MSGV4 DESCENDING.
    READ TABLE T_SLG1_MESSAGES INDEX 1 INTO DATA(LS_SLG1_MESSAGES).
    READ TABLE MT_IWFND_RESULT INDEX 1 INTO DATA(LS_IWFND_RESULT).

*       read the custom table GUI logged messages
    SELECT TIME_STMP, ERROR_TEXT FROM ZREPORT_ERROR
      UP TO 1 ROWS
      INTO @DATA(LS_ZREPORT_ERROR)
      WHERE UNAME = @SY-UNAME
      ORDER BY TIME_STMP DESCENDING.
    ENDSELECT.

    IF LS_SLG1_MESSAGES-TIME_STMP > LS_IWFND_RESULT-TIMESTAMP AND
        LS_SLG1_MESSAGES-TIME_STMP >  LS_ZREPORT_ERROR-TIME_STMP.
      CALL FUNCTION 'FORMAT_MESSAGE'
        EXPORTING
          ID        = LS_SLG1_MESSAGES-MSGID
*         LANG      = '-D'
          NO        = LS_SLG1_MESSAGES-MSGNO
          V1        = LS_SLG1_MESSAGES-MSGV1
          V2        = LS_SLG1_MESSAGES-MSGV2
          V3        = LS_SLG1_MESSAGES-MSGV3
          V4        = LS_SLG1_MESSAGES-MSGV4
        IMPORTING
          MSG       = LAST_ERROR_MSG
        EXCEPTIONS
          NOT_FOUND = 1
          OTHERS    = 2.
      IF SY-SUBRC <> 0.
* Implement suitable error handling here
      ENDIF.
      ERRORTYPE = 'SLG1'.
    ELSEIF LS_IWFND_RESULT-TIMESTAMP > LS_SLG1_MESSAGES-TIME_STMP AND
        LS_IWFND_RESULT-TIMESTAMP > LS_ZREPORT_ERROR-TIME_STMP .
      LAST_ERROR_MSG = LS_IWFND_RESULT-ERROR_TEXT.
      ERRORTYPE = 'IWFND'.
    ELSEIF LS_ZREPORT_ERROR-ERROR_TEXT IS NOT INITIAL.
      LAST_ERROR_MSG = LS_ZREPORT_ERROR-ERROR_TEXT.
      ERRORTYPE = 'GUI'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
