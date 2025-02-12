tableextension 90001 "PRG_Sales Invoice Header Disc." extends "Sales Invoice Header"
{
    fields
    {
        field(90000; "PRG_Discharge Invoice"; Boolean)
        {
            Caption = 'Discharge Invoice';
            DataClassification = CustomerContent;
        }
    }
}