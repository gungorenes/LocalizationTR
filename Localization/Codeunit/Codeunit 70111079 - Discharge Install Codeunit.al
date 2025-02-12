codeunit 90002 "PRG_Discharge Install Codeunit"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    begin
        DiscIntegrationType_EInvoiceTaxTypeCode();
    end;


    local procedure DiscIntegrationType_EInvoiceTaxTypeCode()
    var
        TaxType: Record "PRG_E-Invoice Tax Type Code";
    begin
        if TaxType.Get('301') then begin
            TaxType."PRG_Discharge Integration Type" := TaxType."PRG_Discharge Integration Type"::EInvoice;
            TaxType.Modify();
        end;

        if TaxType.Get('302') then begin
            TaxType."PRG_Discharge Integration Type" := TaxType."PRG_Discharge Integration Type"::EArchive;
            TaxType.Modify();
        end;
    end;

}