page 90000 "PRG_Discharge Sales Invoices"
{
    ApplicationArea = Basic, Suite;
    Caption = 'Discharge Sales Invoices';
    SourceTable = "Sales Header";
    CardPageID = "PRG_Discharge Sales Invoice";
    DataCaptionFields = "Sell-to Customer No.";
    PageType = List;
    UsageCategory = Lists;
    RefreshOnActivate = true;
    SourceTableView = where("PRG_Discharge Invoice" = const(true));
    DeleteAllowed = false;
    ModifyAllowed = false;
    InsertAllowed = false;
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(Control1)
            {
                ShowCaption = false;
                field("No."; Rec."No.")
                {
                    ApplicationArea = Basic, Suite;
                }
                field("Sell-to Customer No."; Rec."Sell-to Customer No.")
                {
                    ApplicationArea = Basic, Suite;
                }
                field("Sell-to Customer Name"; Rec."Sell-to Customer Name")
                {
                    ApplicationArea = Basic, Suite;
                }
                field("External Document No."; Rec."External Document No.")
                {
                    ApplicationArea = Basic, Suite;
                }
                field("Sell-to Country/Region Code"; Rec."Sell-to Country/Region Code")
                {
                    ApplicationArea = Basic, Suite;
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = Basic, Suite;
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = Suite;
                }
                field(Amount; Rec.Amount)
                {
                    ApplicationArea = Basic, Suite;
                }
            }
        }
    }

    actions
    {
        area(navigation)
        {
            group("&Invoice")
            {
                Caption = '&Invoice';
                Image = Invoice;
                action(Statistics)
                {
                    ApplicationArea = Suite;
                    Caption = 'Statistics';
                    Image = Statistics;
                    ShortCutKey = 'F7';
                    trigger OnAction()
                    begin
                        Rec.OpenDocumentStatistics();
                    end;
                }
                action("Co&mments")
                {
                    ApplicationArea = Comments;
                    Caption = 'Co&mments';
                    Image = ViewComments;
                    RunObject = Page "Sales Comment Sheet";
                    RunPageLink = "Document Type" = field("Document Type"),
                                  "No." = field("No."),
                                  "Document Line No." = const(0);
                }
                action(Dimensions)
                {
                    AccessByPermission = TableData Dimension = R;
                    ApplicationArea = Dimensions;
                    Caption = 'Dimensions';
                    Image = Dimensions;
                    ShortCutKey = 'Alt+D';
                    trigger OnAction()
                    begin
                        Rec.ShowDocDim();
                    end;
                }
            }
        }
        area(processing)
        {
            group("P&osting")
            {
                Caption = 'P&osting';
                Image = Post;
                action("Test Report")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Test Report';
                    Ellipsis = true;
                    Image = TestReport;
                    trigger OnAction()
                    begin
                        ReportPrint.PrintSalesHeader(Rec);
                    end;
                }
                action(Post)
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'P&ost';
                    Image = PostOrder;
                    ShortCutKey = 'F9';
                    trigger OnAction()
                    var
                        SalesHeader: Record "Sales Header";
                        SalesBatchPostMgt: Codeunit "Sales Batch Post Mgt.";
                    begin
                        CurrPage.SetSelectionFilter(SalesHeader);
                        if SalesHeader.Count > 1 then
                            SalesBatchPostMgt.RunWithUI(SalesHeader, Rec.Count, ReadyToPostQst)
                        else
                            PostDocument(CODEUNIT::"Sales-Post (Yes/No)");
                    end;
                }
                action(Preview)
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Preview Posting';
                    Image = ViewPostedOrder;
                    ShortCutKey = 'Ctrl+Alt+F9';
                    trigger OnAction()
                    begin
                        ShowPreview();
                    end;
                }
            }
        }

        area(Promoted)
        {
            group(Category_Category5)
            {
                Caption = 'Posting';
                ShowAs = SplitButton;

                actionref(Post_Promoted; Post)
                {
                }
                actionref(Preview_Promoted; Preview)
                {
                }
            }
            group(Category_Category7)
            {
                Caption = 'Request Approval';
            }
            group(Category_Category6)
            {
                Caption = 'Invoice';

                actionref(Dimensions_Promoted; Dimensions)
                {
                }
                actionref(Statistics_Promoted; Statistics)
                {
                }
                actionref("Co&mments_Promoted"; "Co&mments")
                {
                }
                separator(Navigate_Separator)
                {
                }
            }
            group(Category_Category8)
            {
                Caption = 'Navigate';
            }
            group(Category_Report)
            {
                Caption = 'Report';
            }
        }
    }

    var
        ApplicationAreaMgmtFacade: Codeunit "Application Area Mgmt. Facade";
        ReportPrint: Codeunit "Test Report-Print";
        LinesInstructionMgt: Codeunit "Lines Instruction Mgt.";
        OpenPostedSalesInvQst: Label 'The invoice is posted as number %1 and moved to the Posted Sales Invoice window.\\Do you want to open the posted invoice?', Comment = '%1 = posted document number';
        ReadyToPostQst: Label 'The number of invoices that will be posted is %1. \Do you want to continue?', Comment = '%1 - selected count';

    procedure ShowPreview()
    var
        SelectedSalesHeader: Record "Sales Header";
        SalesPostYesNo: Codeunit "Sales-Post (Yes/No)";
    begin
        CurrPage.SetSelectionFilter(SelectedSalesHeader);
        SalesPostYesNo.MessageIfPostingPreviewMultipleDocuments(SelectedSalesHeader, Rec."No.");
        SalesPostYesNo.Preview(Rec);
    end;

    protected procedure PostDocument(PostingCodeunitID: Integer)
    var
        PreAssignedNo: Code[20];
        xLastPostingNo: Code[20];
        IsHandled: Boolean;
    begin
        LinesInstructionMgt.SalesCheckAllLinesHaveQuantityAssigned(Rec);
        PreAssignedNo := Rec."No.";
        xLastPostingNo := Rec."Last Posting No.";

        Rec.SendToPosting(PostingCodeunitID);

        IsHandled := false;
        if IsHandled then
            exit;

        if ApplicationAreaMgmtFacade.IsFoundationEnabled() then
            ShowPostedConfirmationMessage(PreAssignedNo, xLastPostingNo);
    end;

    local procedure ShowPostedConfirmationMessage(PreAssignedNo: Code[20]; xLastPostingNo: Code[20])
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        InstructionMgt: Codeunit "Instruction Mgt.";
    begin
        if (Rec."Last Posting No." <> '') and (Rec."Last Posting No." <> xLastPostingNo) then
            SalesInvoiceHeader.SetRange("No.", Rec."Last Posting No.")
        else begin
            SalesInvoiceHeader.SetCurrentKey("Pre-Assigned No.");
            SalesInvoiceHeader.SetRange("Pre-Assigned No.", PreAssignedNo);
        end;
        if SalesInvoiceHeader.FindFirst() then
            if InstructionMgt.ShowConfirm(StrSubstNo(OpenPostedSalesInvQst, SalesInvoiceHeader."No."),
                 InstructionMgt.ShowPostedConfirmationMessageCode())
            then
                InstructionMgt.ShowPostedDocument(SalesInvoiceHeader, Page::"Sales Invoice List");
    end;
}