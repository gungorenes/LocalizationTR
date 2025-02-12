pageextension 90001 "PRG_Sales Invoice List Disc." extends "Sales Invoice List"
{
    trigger OnOpenPage()
    begin
        Rec.SetRange("PRG_Discharge Invoice", false);
    end;
}