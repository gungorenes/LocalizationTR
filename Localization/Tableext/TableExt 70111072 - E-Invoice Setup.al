tableextension 90002 "PRG_E-Invoice Setup Disc." extends "PRG_E-Invoice Setup"
{
    fields
    {
        field(90000; "PRG_Discharge Inv. No. Series"; Code[20])
        {
            Caption = 'Discharge Invoice No. Series';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
    }
}