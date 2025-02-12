pageextension 90005 "PRG_E-Invoice Tax Type Code" extends "PRG_E-Invoice Tax Type Code"
{
    layout
    {
        addlast(General)
        {
            field("PRG_Discharge Integration Type"; Rec."PRG_Discharge Integration Type")
            {
                ApplicationArea = All;
            }
        }
    }
}