codeunit 90001 "PRG_Discharge Subscribers"
{
    ///<summary> İntaç faturaları için E-Fatura kurulumundaki İntaç Numara Serisi alanından E-Fatura numarası alması. </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"PRG_E-Invoice Management", 'OnBeforeAssignInvoiceID', '', false, false)]
    local procedure OnBeforeAssignInvoiceID_EInvMgt(var EInvHeader: Record "PRG_E-Invoice Header"; var InvoiceID: Text[30]; var IsHandle: Boolean)
    var
        Queue: Record "PRG_E-Invoice Queue";
        EInvSetup: Record "PRG_E-Invoice Setup";
        NoSeriesMgt: Codeunit "No. Series";
    begin
        if EInvHeader."G/L Register Entry No." <> 0 then
            exit;

        Queue.SetRange(UniqueIdentifier, EInvHeader.UUID);
        if not Queue.FindFirst() then
            exit;

        if not Queue."PRG_Discharge Invoice" then
            exit;

        EInvSetup.Get();
        EInvSetup.TestField("PRG_Discharge Inv. No. Series");

        InvoiceID := NoSeriesMgt.GetNextNo(EInvSetup."PRG_Discharge Inv. No. Series", EInvHeader.IssueDate, true);
        IsHandle := true;
    end;

    ///<summary> İntaç oluşturulan faturaların Deftere Nakil sonrası tekrar E-Fatura'ya çağırıldığında mükerrer olmaması için. </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"PRG_E-Invoice Management", 'OnBeforeSetContinueForQueue', '', false, false)]
    local procedure OnBeforeSetContinueForQueue_EInvMgt(GLReg: Record "G/L Register"; sender: Codeunit "PRG_E-Invoice Management"; var Continue: Boolean)
    var
        GLEntry: Record "G/L Entry";
        SalesInvHeader: Record "Sales Invoice Header";
    begin
        GLEntry.SETRANGE("Entry No.", GLReg."From Entry No.", GLReg."To Entry No.");
        GLEntry.FINDFIRST();

        SalesInvHeader.SETRANGE("No.", GLEntry."Document No.");
        SalesInvHeader.SETRANGE("Posting Date", GLEntry."Posting Date");
        SalesInvHeader.SetRange("PRG_Discharge Invoice", true);
        if SalesInvHeader.IsEmpty() then
            exit;

        Continue := false;
    end;

    ///<summary> İntaç E-Faturaları gönderildikten sonra 'Sales Header' tablosunda 'External Document No.' alanının güncellemesi için. </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"PRG_E-Invoice Management", 'OnBeforeUpdateExDocNo', '', false, false)]
    local procedure OnBeforeUpdateExDocNo_EInvMgt(PrmQueue: Record "PRG_E-Invoice Queue"; GLReg: Record "G/L Register"; var IsHandled: Boolean)
    var
        SalesHeader: Record "Sales Header";
    begin
        if not PrmQueue."PRG_Discharge Invoice" then
            exit;

        SalesHeader.SetRange("No.", PrmQueue."PRG_Discharge Document No.");
        if not SalesHeader.FindFirst() then
            exit;

        SalesHeader."External Document No." := PrmQueue.InvoiceID;
        SalesHeader.Modify();
        Commit();

        IsHandled := true;
    end;
}