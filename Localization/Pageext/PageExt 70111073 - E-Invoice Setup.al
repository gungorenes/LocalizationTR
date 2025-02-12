pageextension 90003 "PRG_E-Invoice Setup Disc." extends "PRG_E-Invoice Setup"
{
    layout
    {
        addafter("E-Invoice No. Series")
        {
            field("PRG_Discharge Inv. No. Series"; Rec."PRG_Discharge Inv. No. Series")
            {
                ApplicationArea = All;
            }
        }
    }
}
