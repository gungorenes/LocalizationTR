page 90003 "PRG_Posting Date Dialog"
{
    ApplicationArea = All;
    Caption = '_Posting Date Dialog';
    PageType = ConfirmationDialog;


    layout
    {
        area(Content)
        {
            field(PostingDate; PostingDate)
            {
                ApplicationArea = All;
                Importance = Standard;
            }
        }
    }

    var
        PostingDate: Date;


    procedure SetPostingDate(_PostingDate: Date)
    begin
        PostingDate := _PostingDate;
    end;

    procedure GetPostingDate(var _PostingDate: Date)
    begin
        _PostingDate := PostingDate;
    end;
}