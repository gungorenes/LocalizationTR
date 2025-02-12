tableextension 90003 "PRG_E-Invoice Queue Disc." extends "PRG_E-Invoice Queue"
{
    fields
    {
        field(70111070; "PRG_Discharge Invoice"; Boolean)
        {
            Caption = 'Discharge Invoice';
            DataClassification = CustomerContent;
        }
        field(70111071; "PRG_Discharge Document No."; Code[20])
        {
            Caption = 'Discharge Document No.';
            DataClassification = CustomerContent;
        }
    }
}