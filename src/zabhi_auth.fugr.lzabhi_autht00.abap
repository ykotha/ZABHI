*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZABHI_AUTH......................................*
DATA:  BEGIN OF STATUS_ZABHI_AUTH                    .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZABHI_AUTH                    .
CONTROLS: TCTRL_ZABHI_AUTH
            TYPE TABLEVIEW USING SCREEN '0009'.
*.........table declarations:.................................*
TABLES: *ZABHI_AUTH                    .
TABLES: ZABHI_AUTH                     .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
