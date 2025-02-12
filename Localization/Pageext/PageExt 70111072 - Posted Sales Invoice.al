pageextension 90002 "PRG_Posted Sales Invoice Disc." extends "Posted Sales Invoice"
{
    layout
    {
        addlast(General)
        {
            field("PRG_Discharge Invoice"; Rec."PRG_Discharge Invoice")
            {
                ApplicationArea = All;
            }
        }
    }
}
