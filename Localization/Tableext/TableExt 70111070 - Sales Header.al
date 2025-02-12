tableextension 90000 "PRG_Sales Header Disc." extends "Sales Header"
{
    fields
    {
        field(70111070; "PRG_Discharge Invoice"; Boolean)
        {
            Caption = 'Discharge Invoice';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}