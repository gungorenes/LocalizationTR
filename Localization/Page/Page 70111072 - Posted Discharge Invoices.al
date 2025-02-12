page 90002 "PRG_Posted Disc Sales Invoices"
{
    ApplicationArea = All;
    Caption = 'Posted Discharge Sales Invoices';
    PageType = List;
    SourceTable = "Sales Invoice Header";
    UsageCategory = History;
    SourceTableView = where("PRG_Discharge Invoice" = filter(true));
    CardPageID = "Posted Sales Invoice";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                    ToolTip = 'Specifies the posted invoice number.';
                }
                field("Sell-to Customer No."; Rec."Sell-to Customer No.")
                {
                    ToolTip = 'Specifies the number of the customer the invoice concerns.';
                }
                field("Sell-to Customer Name"; Rec."Sell-to Customer Name")
                {
                    ToolTip = 'Specifies the name of the customer that you shipped the items on the invoice to.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ToolTip = 'Specifies the date on which the invoice was posted.';
                }
                field("PRG_E-Platform Type"; Rec."PRG_E-Platform Type")
                {
                    ToolTip = 'Specifies the value of the E-Platform Type field.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ToolTip = 'Specifies the currency code of the invoice.';
                }
                field("Order No."; Rec."Order No.")
                {
                    ToolTip = 'Specifies the number of the sales order that this invoice was posted from.';
                }
                field(Amount; Rec.Amount)
                {
                    ToolTip = 'Specifies the total, in the currency of the invoice, of the amounts on all the invoice lines. The amount does not include VAT.';
                }
                field("Amount Including VAT"; Rec."Amount Including VAT")
                {
                    ToolTip = 'Specifies the total of the amounts, including VAT, on all the lines on the document.';
                }
            }
        }
    }
}