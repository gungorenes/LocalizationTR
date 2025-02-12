pageextension 90004 "PRG_E-Inv Outgoing Queue Disc." extends "PRG_E-Invoice Outgoing Queue"
{
    layout
    {
        addlast(General)
        {
            field("Discharge Invoice"; Rec."PRG_Discharge Invoice")
            {
                ApplicationArea = All;
            }
            field("Discharge Document No."; Rec."PRG_Discharge Document No.")
            {
                ApplicationArea = All;
            }
        }
    }
}