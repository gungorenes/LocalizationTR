pageextension 90000 "PRG_Sales Invoice Disc." extends "Sales Invoice"
{
    layout
    {

    }

    actions
    {
        addafter(Approval)
        {
            action(PRG_CreateDischargeInvoice)
            {
                Caption = 'Create Discharge E-Invoice';
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                Image = CreateCreditMemo;
                trigger OnAction()
                var
                    DischargeMgt: Codeunit "PRG_Discharge Management";
                begin
                    DischargeMgt.CreateEInvoice(Rec);
                    Rec.SetHideValidationDialog(true);
                    CurrPage.Update(true);
                end;
            }
        }
    }
}