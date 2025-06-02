.define appversion_major  0
.define appversion_minor  1
.define appversion_patch  1

.segment "SIGNATURE"
    .byt "BASLOAD", appversion_major, appversion_minor, appversion_patch
.CODE
