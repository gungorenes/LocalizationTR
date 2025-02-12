codeunit 90000 "PRG_Discharge Management"
{
    var
        Cust: Record Customer;
        ExportSetup: Record "PRG_E-Export Setup";
        EInvSetup: Record "PRG_E-Invoice Setup";
        GlobCVInfo: Record "PRG_E-Invoice CV Info.";
        GlobEInvHeader: Record "PRG_E-Invoice Header";
        GlobEInvLine: Record "PRG_E-Invoice Line";
        GlobEInvTaxLine: Record "PRG_E-Invoice Tax Line";
        GotExportSetup: Boolean;
        GotInvSetup: Boolean;
        Text001: Label 'Only: ';
        Text002: Label 'Tax Type empty!';
        Text003: Label 'Tax Type missing!';
        Text004: Label 'E-Invoice is not activated! Activate the E-Invoice and run the process again.';
        Text005: Label 'Discharge E-Invoice created.';
        Text006: Label 'The document status must be released!';
        Text007: Label 'E-Invoice Setup not found!';
        Text008: Label 'Discharge E-Invoice already exists, please check the Outgoing E-Invoices page!';
        Text009: Label 'Have you made a Posting Preview for the Discharge Invoice? Do you want to continue?';
        Text010: Label 'Process Stopped!';
        Text011: Label 'E-Invoice Setup not found!';
        Text012: Label 'There cannot be different E-Invoice Tax Type Codes in Sales Lines!';
        Text013: Label 'Do you want update Posting Date?';

    procedure UpdatePostingDate(var SalesHeader: Record "Sales Header")
    var
        PostingDate: Date;
        Dialog: Page "PRG_Posting Date Dialog";
    begin
        Dialog.SetPostingDate(SalesHeader."Posting Date");
        if Dialog.RunModal() = Action::Yes then begin
            Dialog.GetPostingDate(PostingDate);

            if not Confirm(Text013) then
                Error(Text010);

            SalesHeader.SetHideValidationDialog(true);
            SalesHeader.SetStatus(0);
            SalesHeader.Validate("Posting Date", PostingDate);
            SalesHeader.SetStatus(1);
        end;
    end;

    procedure CancelDischargeInv(var SalesHeader: Record "Sales Header")
    var
        Queue: Record "PRG_E-Invoice Queue";
    begin
        Queue.SetRange("PRG_Discharge Invoice", true);
        Queue.SetRange("PRG_Discharge Document No.", SalesHeader."No.");
        if Queue.FindFirst() then
            Error('--')
        else begin
            SalesHeader.SetHideValidationDialog(true);
            SalesHeader.SetStatus(0);
            SalesHeader.Validate("PRG_Discharge Invoice", false);
            SalesHeader.Modify();
        end;
    end;

    local procedure CheckEInvQueue(var SalesHeader: Record "Sales Header")
    var
        Queue: Record "PRG_E-Invoice Queue";
    begin
        Queue.SetRange("PRG_Discharge Invoice", true);
        Queue.SetRange("PRG_Discharge Document No.", SalesHeader."No.");
        if not Queue.IsEmpty() then
            Error(Text008);
    end;

    procedure CreateEInvoice(var SalesHeader: Record "Sales Header")
    var
        GlobRefLine: Record "PRG_E-Invoice Reference Buffer";
        SalesLine: Record "Sales Line";
        SalesCommLine: Record "Sales Comment Line";
        TaxType: Record "PRG_E-Invoice Tax Type Code";
        Queue: Record "PRG_E-Invoice Queue";
        ShipToAddr: Record "Ship-to Address";
        NumberReader: Codeunit "PRG_E-Invoice Number Reader";
        EInvMgt: Codeunit "PRG_E-Invoice Management";
        RecRef: RecordRef;
        DiscAmt: Decimal;
        HeaderEntryNo: Integer;
        TRWord: Text;
        LineNo: Integer;
        ItemName: Text;
        Desc: Text;
        EInvCheckFunctions: Codeunit "PRG_E-Invoice Check Functions";
    begin
        if SalesHeader.Status <> SalesHeader.Status::Released then
            Error(Text006);

        EInvCheckFunctions.CheckFieldForSalesPost(SalesHeader);
        CheckEInvQueue(SalesHeader);

        if not EInvMgt.IsEInvActivated(SalesHeader."Posting Date") then
            Error(Text011);

        if not Confirm(Text009) then
            Error(Text010);

        GetInvSetup();
        GetExportSetup();
        FillCVInfoForExport(SalesHeader);

        if Queue.FINDLAST() then;
        Queue.INIT();
        Queue.EntryNo := Queue.EntryNo + 1;
        Queue.Type := Queue.Type::Outbox;
        Queue."Queue Status" := Queue."Queue Status"::New;
        Queue.IntegrationType := GlobCVInfo."Integration Type"; //enes
        Queue.ProfileID := GlobEInvHeader.ProfileID::EExport; //enes
        Queue.InvoiceType := GlobEInvHeader.InvoiceType::Exception; //enes
        Queue.UniqueIdentifier := CREATEGUID();
        Queue.CreationDateTime := CURRENTDATETIME;
        Queue.CreatedBy := CopyStr(USERID(), 1, MaxStrLen(Queue.CreatedBy));
        Queue.CVNo := GlobCVInfo."CV No.";
        Queue.CVName := GlobCVInfo."CV Name";
        Queue.CVRegistrationNo := Cust."VAT Registration No.";
        RecRef.GETTABLE(SalesHeader);
        Queue.ERPRecordID := RecRef.RECORDID;
        Queue.INSERT();

        GlobEInvHeader.INIT();
        GlobEInvHeader.UUID := Queue.UniqueIdentifier;
        GlobEInvHeader."Invoice ID" := Queue.InvoiceID;
        GlobEInvHeader."G/L Register Entry No." := Queue.GLRegisterEntryNo;
        GlobEInvHeader.CopyIndicator := 'false';
        GlobEInvHeader."Country/Region Code" := SalesHeader."Bill-to Country/Region Code";
        GlobEInvHeader."Company ID" := Cust."VAT Registration No.";
        GlobEInvHeader.IssueTime := TIME;
        GlobEInvHeader.CustNo := GlobCVInfo."CV No.";
        GlobEInvHeader.CustRegistrationNo := GlobCVInfo."Tax Registration No.";
        GlobEInvHeader.CustTaxSchemeID := GlobCVInfo."TaxSchemeID Buffer";
        GlobEInvHeader.CustName := CopyStr(GlobCVInfo."CV Name", 1, MaxStrLen(GlobEInvHeader.CustName));
        GlobEInvHeader.CustFirstName := CopyStr(GlobCVInfo."First Name", 1, MaxStrLen(GlobEInvHeader.CustFirstName));
        GlobEInvHeader.CustFamilyName := CopyStr(GlobCVInfo."Family Name", 1, MaxStrLen(GlobEInvHeader.CustFamilyName));
        GlobEInvHeader.AllowanceChargeIndicator := 'false';
        GlobEInvHeader.IntegrationType := GlobCVInfo."Integration Type";
        GlobEInvHeader.CustBuildingNumber := '';
        GlobEInvHeader.Type := GlobEInvHeader.Type::Outbox;

        SalesHeader.CALCFIELDS(Amount, "Amount Including VAT");
        DiscAmt := ROUND(CalcSalesInvDiscAmt(SalesHeader), 0.01);
        GlobEInvHeader.InvoiceType := Queue.InvoiceType;
        GlobEInvHeader.DocumentCurrencyCode := EInvMgt.GetCurrCode(SalesHeader."Currency Code");
        if (SalesHeader."Currency Factor" <> 0) AND (SalesHeader."Currency Factor" <> 1) then
            GlobEInvHeader.DocumentCurrencyRate := ROUND(1 / SalesHeader."Currency Factor", 0.00001)
        else
            GlobEInvHeader.DocumentCurrencyRate := 1;

        GlobEInvHeader.OrderNo := SalesHeader."No.";
        GlobEInvHeader.OrderDate := SalesHeader."Order Date";

        Cust.get(SalesHeader."Bill-to Customer No.");
        if SalesHeader."Ship-to Code" <> '' then
            if ShipToAddr.GET(Cust."No.", SalesHeader."Ship-to Code") then
                GlobEInvHeader.CustBranchCode := ShipToAddr.Code;
        GlobEInvHeader.CustWebsiteURI := CopyStr(Cust."Home Page", 1, MaxStrLen(GlobEInvHeader.CustWebsiteURI));
        if (EInvSetup."E-Invoice Addres" = EInvSetup."E-Invoice Addres"::"Fatura Adresi") or
           (SalesHeader."Ship-to Code" = '') then begin
            GlobEInvHeader.CustName := CopyStr(SalesHeader."Bill-to Name" + ' ' + SalesHeader."Bill-to Name 2", 1, MaxStrLen(GlobEInvHeader.CustName));
            if SalesHeader."Bill-to County" <> '' then
                GlobEInvHeader.CustCitySubdivisionName := SalesHeader."Bill-to County"
            else begin
                Cust.TESTFIELD(County);
                GlobEInvHeader.CustCitySubdivisionName := Cust.County;
            end;
            if SalesHeader."Bill-to City" <> '' then
                GlobEInvHeader.CustCityName := SalesHeader."Bill-to City"
            else begin
                Cust.TESTFIELD(City);
                GlobEInvHeader.CustCityName := Cust.City
            end;
            GlobEInvHeader.CustPostalZone := SalesHeader."Bill-to Post Code";
            if SalesHeader."Bill-to Country/Region Code" <> '' then
                GlobEInvHeader.CustCountryName := EInvMgt.GetCountryCode(SalesHeader."Bill-to Country/Region Code")
            else
                GlobEInvHeader.CustCountryName := EInvMgt.GetCountryCode(Cust."Country/Region Code");
            GlobEInvHeader.CustStreetName := SalesHeader."Bill-to Address" + ' ' + SalesHeader."Bill-to Address 2";
        end else begin
            GlobEInvHeader.CustName := CopyStr(SalesHeader."Ship-to Name" + ' ' + SalesHeader."Ship-to Name 2", 1, MaxStrLen(GlobEInvHeader.CustName));
            if SalesHeader."Ship-to County" <> '' then
                GlobEInvHeader.CustCitySubdivisionName := SalesHeader."Ship-to County"
            else begin
                Cust.TESTFIELD(County);
                GlobEInvHeader.CustCitySubdivisionName := Cust.County;
            end;
            if SalesHeader."Ship-to City" <> '' then
                GlobEInvHeader.CustCityName := SalesHeader."Ship-to City"
            else begin
                Cust.TESTFIELD(City);
                GlobEInvHeader.CustCityName := Cust.City
            end;
            GlobEInvHeader.CustPostalZone := SalesHeader."Ship-to Post Code";
            if SalesHeader."Ship-to Country/Region Code" <> '' then
                GlobEInvHeader.CustCountryName := EInvMgt.GetCountryCode(SalesHeader."Ship-to Country/Region Code")
            else
                GlobEInvHeader.CustCountryName := EInvMgt.GetCountryCode(Cust."Country/Region Code");
            GlobEInvHeader.CustStreetName := SalesHeader."Ship-to Address" + ' ' + SalesHeader."Ship-to Address 2";
        end;

        GlobEInvHeader.CustTaxOfficeName := SalesHeader."Tax Area Code";
        GlobEInvHeader.CustTelephone := Cust."Phone No.";
        GlobEInvHeader.CustTelefax := Cust."Fax No.";
        GlobEInvHeader.CustElectronicMail := GlobCVInfo."E-mail Address";
        GlobEInvHeader.CustIdentifier := '';
        GlobEInvHeader.PaymentMethodNote := EInvMgt.GetEArchPaymentMethod(SalesHeader."Payment Method Code");
        GlobEInvHeader.PaymentDueDate := SalesHeader."Due Date";
        GlobEInvHeader.PayableAmount := SalesHeader."Amount Including VAT";
        GlobEInvHeader.IssueDate := SalesHeader."Posting Date";
        GlobEInvHeader.IssueTime := Time;
        GlobEInvHeader.PaymentMethodNote := CopyStr(GetEArchPaymentMethod(SalesHeader."Payment Method Code"), 1, MaxStrLen(GlobEInvHeader.PaymentMethodNote));
        if SalesHeader."Amount Including VAT" <> 0 then
            GlobEInvHeader.AllowanceChargeRate := ROUND((DiscAmt / (SalesHeader.Amount + DiscAmt)), 0.0001)
        else
            GlobEInvHeader.AllowanceChargeRate := 1;
        GlobEInvHeader.AllowanceChargeAmtInvoice := DiscAmt;
        GlobEInvHeader.IntegrationType := GlobEInvHeader.IntegrationType::EArchive;

        HeaderEntryNo := EInvMgt.FindNextHeaderEntryNo();
        if HeaderEntryNo <> 0 then begin
            GlobEInvHeader."Entry No." := HeaderEntryNo;
            GlobEInvHeader.INSERT();

            SalesHeader.CALCFIELDS("Amount Including VAT");
            TRWord := '';
            if SalesHeader."Amount Including VAT" <> 0 then
                TRWord := NumberReader.GetWords('', SalesHeader."Amount Including VAT", SalesHeader."Currency Code");

            EInvMgt.InsertRefBuffer(HeaderEntryNo, 0, GlobRefLine."Reference Type"::Note, Text001 + TRWord, 0D);

            SalesCommLine.SETRANGE("Document Type", SalesCommLine."Document Type"::"Posted Invoice");
            SalesCommLine.SETRANGE("No.", SalesHeader."No.");
            if SalesCommLine.FINDSET() then
                repeat
                    EInvMgt.InsertRefBuffer(HeaderEntryNo, 0, GlobRefLine."Reference Type"::Note, SalesCommLine.Comment, 0D);
                until SalesCommLine.NEXT() = 0;

            SalesLine.SetRange("Document Type", SalesHeader."Document Type");
            SalesLine.SetRange("Document No.", SalesHeader."No.");
            if SalesLine.FindSet() then
                repeat
                    if (SalesLine.Type.AsInteger() > 0) and (SalesLine."No." <> '') and (SalesLine.Quantity <> 0) then begin
                        LineNo += 1;
                        case EInvSetup."Item Name Source" of
                            EInvSetup."Item Name Source"::LineDescription:
                                begin
                                    ItemName := SalesLine.Description;
                                    Desc := SalesLine.Description;
                                end;
                            EInvSetup."Item Name Source"::AccName:
                                begin
                                    ItemName := GetSourceDesc(SalesLine.Type.AsInteger(), SalesLine."No.");
                                    Desc := SalesLine.Description;
                                end;
                        end;

                        OnBeforeInsertInvoiceLine(GlobEInvHeader, SalesLine, ItemName, Desc);

                        InsertInvLine(HeaderEntryNo,
                            LineNo,
                            SalesLine."No.",
                            SalesLine.Quantity,
                            (SalesLine.Quantity * SalesLine."Unit Price") -
                            (SalesLine."Line Discount Amount" + SalesLine."Inv. Discount Amount"),
                            SalesLine."Line Discount Amount" + SalesLine."Inv. Discount Amount",
                            SalesLine.Amount,
                            SalesLine."Amount Including VAT" - SalesLine.Amount,
                            ItemName,
                            Desc,
                            SalesLine."Unit Price",
                            SalesLine."Unit of Measure Code",
                            FindSalesCrossRef(SalesLine),
                            FindSalesBarcode(SalesLine),
                            SalesHeader."Shipment Method Code",
                            SalesHeader."Transport Method",
                            SalesLine."PRG_Tariff Number",
                            GlobEInvHeader.CustCountryName,
                            GlobEInvHeader.CustCityName,
                            SalesLine."PRG_Package Brand",
                            SalesLine."PRG_Packagin Type Code",
                            SalesLine."PRG_Actual Package Quantity");

                        TaxType.INIT();
                        if SalesLine."PRG_E-Invoice Tax Type Code" <> '' then
                            TaxType.GET(SalesLine."PRG_E-Invoice Tax Type Code");

                        SetTaxLine(HeaderEntryNo, SalesLine."PRG_E-Invoice Tax Type Code",
                            SalesLine."Amount Including VAT" - SalesLine.Amount + SalesLine."Unit Volume",
                            SalesLine.Amount, SalesLine."VAT %");
                    end;
                until SalesLine.Next() = 0;

            GlobEInvHeader.CALCFIELDS(TaxExclusiveAmount, TaxInclusiveAmount);
            Queue.TaxExclusiveAmount := GlobEInvHeader.TaxExclusiveAmount;
            Queue.TaxInclusiveAmount := GlobEInvHeader.TaxInclusiveAmount;
            Queue."PRG_Discharge Invoice" := true;
            Queue."PRG_Discharge Document No." := SalesHeader."No.";
            Queue.IssueDate := SalesHeader."Posting Date";
            Queue.Modify();

            SalesHeader."PRG_Discharge Invoice" := true;
            SalesHeader.Modify();

            EInvMgt.InsertRefBuffer(HeaderEntryNo, 0, GlobRefLine."Reference Type"::PaymentMethod, GetEArchPaymentMethod(SalesHeader."Payment Method Code"), SalesHeader."Due Date");
            Message(Text005);
        end;
    end;

    procedure GetEArchPaymentMethod(PMCode: Code[30]): Code[50]
    var
        CodeMapping: Record "PRG_E-Invoice Code Mapping";
    begin
        if PMCode <> '' then begin
            if not GetInvSetup() then
                ERROR(Text007);
            CodeMapping.GET(CodeMapping.Type::EArchPayMethod, PMCode);
            CodeMapping.TESTFIELD("Destination Code");
            exit(CodeMapping."Destination Code");
        end;
    end;

    procedure InsertInvLine(HeaderEntryNo: Integer; LineNo: Integer; ItemNo: Code[20]; Qty: Decimal; LineExtAmt: Decimal; ChargeAmt: Decimal; TaxableAmt: Decimal; TaxAmt: Decimal; ItemName: Text[250]; Desc: Text[250]; UnitPrice: Decimal; UOMCode: Code[20]; CrossRefNo: Text[30]; BarcodeNo: Text[30]; ShipmentMethod: Code[10]; TransMethod: Code[10]; TariffNumber: Code[20]; CountryName: Text[30]; CityName: Text[30]; PackageBrand: Code[20]; PackageType: Code[20]; PackageQty: Decimal)
    begin
        GlobEInvLine.INIT();
        GlobEInvLine."Header Entry No." := HeaderEntryNo;
        GlobEInvLine."Line No." := LineNo;
        GlobEInvLine."Sellers Item Identification" := ItemNo;
        GlobEInvLine.Quantity := ROUND(Qty, 0.00001);
        GlobEInvLine."Line Extension Amount" := ABS(ROUND(LineExtAmt, 0.01));
        GlobEInvLine."Allowance Charge Indicator" := 'false';
        GlobEInvLine."Allowance Charge Amount" := ABS(ROUND(ChargeAmt, 0.01));
        if ChargeAmt <> 0 then
            GlobEInvLine."Allowance Charge Rate" := ABS(ROUND((ChargeAmt / (TaxableAmt + ChargeAmt)), 0.0001));
        GlobEInvLine."Item Name" := ItemName;
        GlobEInvLine.Description := Desc;
        GlobEInvLine."Unit Price" := ABS(ROUND(UnitPrice, 0.00001));
        GlobEInvLine."Buyers Item Identification" := CrossRefNo;
        GlobEInvLine."Manu. Item Identification" := BarcodeNo;
        GlobEInvLine."Unit Of Measure Code" := GetUOMCode(UOMCode);
        GlobEInvLine."Delivery Terms" := ShipmentMethod;
        GlobEInvLine."Transport Mode Code" := TransMethod;
        GlobEInvLine."GTIP No." := TariffNumber;
        GlobEInvLine."Delivery Country Name" := CountryName;
        GlobEInvLine."Delivery City Name" := CityName;
        GlobEInvLine."Package Brand" := PackageBrand;
        GlobEInvLine."Packagin Type Code" := PackageType;
        GlobEInvLine."Actual Package Quantity" := PackageQty;
        GlobEInvLine.INSERT();
    end;

    procedure SetTaxLine(HeaderEntryNo: Integer; TaxTypeCode: Code[20]; TaxAmt: Decimal; BaseAmt: Decimal; TaxPercent: Decimal)
    begin
        InsertTaxLine(HeaderEntryNo, TaxTypeCode, ROUND(TaxAmt, 0.01), ROUND(BaseAmt, 0.01), ROUND(TaxPercent, 0.01), FALSE);
        InsertTaxLine(HeaderEntryNo, TaxTypeCode, ROUND(TaxAmt, 0.01), ROUND(BaseAmt, 0.01), ROUND(TaxPercent, 0.01), TRUE);
    end;

    procedure InsertTaxLine(HeaderEntryNo: Integer; TaxTypeCode: Code[20]; TaxAmt: Decimal; BaseAmt: Decimal; TaxPercent: Decimal; IsHeader: Boolean)
    var
        TaxType: Record "PRG_E-Invoice Tax Type Code";
    begin

        if TaxTypeCode = '' then
            ERROR(Text002);

        TaxType.GET(TaxTypeCode);
        CLEAR(GlobEInvTaxLine);

        CASE TRUE OF

            TaxTypeCode = EInvSetup."VAT Tax Type Code", TaxType.Type = TaxType.Type::Exported:
                begin
                    if TaxAmt = 0 then
                        EXIT;
                    if TaxPercent = 0 then
                        if BaseAmt <> 0 then
                            TaxPercent := ROUND(TaxAmt / BaseAmt * 100, 1);
                end;

            else begin
                if TaxPercent = 0 then
                    TaxPercent := TaxType."Tax Rate";
                if TaxType.Type = TaxType.Type::WitholdingCode then
                    BaseAmt := TaxAmt;
                TaxAmt := BaseAmt * TaxPercent / 100
            end;
        end;

        case true of
            TaxType.Code = EInvSetup."Sales Exemption Tax Code":
                TaxTypeCode := EInvSetup."VAT Tax Type Code";
            TaxType.Type = TaxType.Type::ExceptionCode:
                TaxTypeCode := EInvSetup."VAT Tax Type Code";
            TaxType.Type = TaxType.Type::PartialExceptionCode:
                TaxTypeCode := EInvSetup."VAT Tax Type Code";
        end;

        GlobEInvTaxLine.SETRANGE("Header Entry No.", HeaderEntryNo);
        if IsHeader then
            GlobEInvTaxLine.SETRANGE("Header Line No.", 0)
        else
            GlobEInvTaxLine.SETRANGE("Header Line No.", GlobEInvLine."Line No.");

        if (IsHeader) AND (TaxType.Type = TaxType.Type::Exported) then
            GlobEInvTaxLine.SETRANGE(TaxTypeCode, EInvSetup."VAT Tax Type Code")
        else
            GlobEInvTaxLine.SETRANGE(TaxTypeCode, TaxTypeCode);

        GlobEInvTaxLine.SETRANGE(TaxPercent, TaxPercent);
        if not GlobEInvTaxLine.FINDLAST() then begin

            GlobEInvTaxLine.SETRANGE(TaxTypeCode);
            GlobEInvTaxLine.SETRANGE(TaxPercent);
            if not GlobEInvTaxLine.FINDLAST() then
                GlobEInvTaxLine."Line No." := 10000
            else
                GlobEInvTaxLine."Line No." := GlobEInvTaxLine."Line No." + 10000;

            GlobEInvTaxLine.INIT();
            GlobEInvTaxLine."Header Entry No." := HeaderEntryNo;
            if IsHeader then begin
                GlobEInvTaxLine.Type := GlobEInvTaxLine.Type::Header;
                GlobEInvTaxLine."Header Line No." := 0;
            end else begin
                GlobEInvTaxLine.Type := GlobEInvTaxLine.Type::Line;
                GlobEInvTaxLine."Header Line No." := GlobEInvLine."Line No.";
            end;

            GlobEInvTaxLine.TaxTypeCode := TaxTypeCode;

            case TaxType.Type of
                TaxType.Type::VAT:
                    GlobEInvTaxLine.TaxTypeName := 'KDV';
                TaxType.Type::WitholdingCode:
                    GlobEInvTaxLine.TaxTypeName := 'TEVKIFAT';
                TaxType.Type::ExceptionCode:
                    GlobEInvTaxLine.TaxTypeName := 'ISTISNA';
                TaxType.Type::PartialExceptionCode:
                    GlobEInvTaxLine.TaxTypeName := 'ISTISNA';
                TaxType.Type::SpecificBaseCode:
                    GlobEInvTaxLine.TaxTypeName := 'OZELMATRAH';
                TaxType.Type::Exported:
                    begin
                        GlobEInvTaxLine.TaxTypeName := 'KDV';
                        GlobEInvTaxLine.TaxTypeCode := EInvSetup."VAT Tax Type Code";
                    end
                else
                    GlobEInvTaxLine.FIELDERROR(TaxTypeName, Text003);
            end;

            if TaxType.Type <> TaxType.Type::Exported then
                GlobEInvTaxLine.TaxTypeName := TaxType.Description;

            case true of
                TaxType.Code = EInvSetup."Sales Exemption Tax Code":
                    GlobEInvTaxLine.TaxTypeCode := EInvSetup."VAT Tax Type Code";
                TaxType.Type = TaxType.Type::ExceptionCode:
                    GlobEInvTaxLine.TaxTypeCode := EInvSetup."VAT Tax Type Code";
                TaxType.Type = TaxType.Type::PartialExceptionCode:
                    GlobEInvTaxLine.TaxTypeCode := EInvSetup."VAT Tax Type Code";
                TaxType.Type = TaxType.Type::Exported:
                    GlobEInvTaxLine.TaxTypeCode := EInvSetup."VAT Tax Type Code";
                else
                    GlobEInvTaxLine.TaxTypeCode := TaxTypeCode;
            end;

            case TaxType.Type of
                TaxType.Type::VAT:
                    if (TaxTypeCode = EInvSetup."VAT Tax Type Code") OR (TaxTypeCode = EInvSetup."Sales Exemption Tax Code") then
                        GlobEInvTaxLine.TaxType := GlobEInvTaxLine.TaxType::VAT
                    else
                        GlobEInvTaxLine.TaxType := GlobEInvTaxLine.TaxType::Other;
                TaxType.Type::WitholdingCode:
                    begin
                        GlobEInvTaxLine.TaxType := GlobEInvTaxLine.TaxType::Witholding;
                        GlobEInvHeader.InvoiceType := GlobEInvHeader.InvoiceType::Withholding;
                    end;
                TaxType.Type::ExceptionCode:
                    begin
                        GlobEInvTaxLine.TaxType := GlobEInvTaxLine.TaxType::Exception;
                        GlobEInvHeader.InvoiceType := GlobEInvHeader.InvoiceType::Exception;
                    end;
                TaxType.Type::PartialExceptionCode:
                    begin
                        GlobEInvTaxLine.TaxType := GlobEInvTaxLine.TaxType::PartialException;
                        GlobEInvHeader.InvoiceType := GlobEInvHeader.InvoiceType::Exception;
                    end;
                TaxType.Type::SpecificBaseCode:
                    begin
                        GlobEInvTaxLine.TaxType := GlobEInvTaxLine.TaxType::SpecificBase;
                        GlobEInvHeader.InvoiceType := GlobEInvHeader.InvoiceType::SpecificBase;
                    end;
                TaxType.Type::Exported:
                    GlobEInvHeader.InvoiceType := GlobEInvHeader.InvoiceType::Exported;
            end;

            GlobEInvTaxLine.TaxPercent := ABS(TaxPercent);
            GlobEInvTaxLine.TaxAmount := ABS(TaxAmt);
            GlobEInvTaxLine.TaxExclusiveAmount := ABS(BaseAmt);
            GlobEInvTaxLine.TaxInclusiveAmount := GlobEInvTaxLine.TaxExclusiveAmount + GlobEInvTaxLine.TaxAmount;

            if (TaxType.Type = TaxType.Type::ExceptionCode) OR
               (TaxType.Type = TaxType.Type::PartialExceptionCode) OR (TaxType.Code = EInvSetup."Sales Exemption Tax Code") OR (TaxType.Type = TaxType.Type::Exported) then begin
                GlobEInvTaxLine."TaxExemption Reason Code" := TaxType.Code;
                GlobEInvTaxLine."TaxExemption Reason Desc" := TaxType.Description;
            end;

            if GlobEInvHeader.ProfileID = GlobEInvHeader.ProfileID::EExport then begin
                GlobEInvHeader.InvoiceType := GlobEInvHeader.InvoiceType::Exception;
                GetExportSetup();
                ExportSetup.TESTFIELD("Default Exemption Tax Code");
                GlobEInvTaxLine."TaxExemption Reason Code" := ExportSetup."Default Exemption Tax Code";
                GlobEInvTaxLine."TaxExemption Reason Desc" := ExportSetup."Default Exemption Tax Desc";
            end;

            GlobEInvTaxLine.INSERT();
            CalcTaxSeqNumber(GlobEInvTaxLine);

        end else begin
            GlobEInvTaxLine.TaxAmount := GlobEInvTaxLine.TaxAmount + ABS(TaxAmt);
            GlobEInvTaxLine.TaxExclusiveAmount := GlobEInvTaxLine.TaxExclusiveAmount + ABS(BaseAmt);
            GlobEInvTaxLine.TaxInclusiveAmount := GlobEInvTaxLine.TaxExclusiveAmount + GlobEInvTaxLine.TaxAmount;
            GlobEInvTaxLine.MODIFY();
        end;

    end;

    procedure CalcTaxSeqNumber(pTaxLine: Record "PRG_E-Invoice Tax Line"): Integer
    var
        TaxLine: Record "PRG_E-Invoice Tax Line";
        TaxTypeCode: Record "PRG_E-Invoice Tax Type Code";
        TempTaxTypeCode: Record "PRG_E-Invoice Tax Type Code" temporary;
        SeqNo: Integer;
    begin
        TaxLine.RESET();
        TaxLine.SETRANGE("Header Entry No.", pTaxLine."Header Entry No.");
        TaxLine.SETRANGE("Header Line No.", pTaxLine."Header Line No.");
        TaxLine.FindSet();
        repeat
            if not TempTaxTypeCode.GET(TaxLine.TaxTypeCode) then begin
                TaxTypeCode.GET(TaxLine.TaxTypeCode);
                TempTaxTypeCode := TaxTypeCode;
                TempTaxTypeCode.INSERT();
            end;
        until TaxLine.NEXT() = 0;

        TempTaxTypeCode.SETCURRENTKEY("Calculation Sequence Number");
        TempTaxTypeCode.FindSet();
        SeqNo := 0;
        repeat
            SeqNo := SeqNo + 1;
            TaxLine.SETRANGE(TaxTypeCode, TempTaxTypeCode.Code);
            TaxLine.FINDFIRST();
            TaxLine.CalculationSequenceNumeric := SeqNo;
            TaxLine.MODIFY();
        until TempTaxTypeCode.NEXT() = 0;
    end;

    procedure FindSalesBarcode(var SalesLine: Record "Sales Line"): Text[50]
    var
        ItemCrossReference: Record "Item Reference";
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit('');

        ItemCrossReference.RESET();
        ItemCrossReference.SETRANGE("Item No.", SalesLine."No.");
        ItemCrossReference.SETRANGE("Variant Code", SalesLine."Variant Code");
        ItemCrossReference.SETRANGE("Unit of Measure", SalesLine."Unit of Measure Code");
        ItemCrossReference.SETRANGE("Reference Type", ItemCrossReference."Reference Type"::"Bar Code");
        ItemCrossReference.SETRANGE("Reference Type No.", SalesLine."Sell-to Customer No.");
        if ItemCrossReference.FINDFIRST() then
            exit(ItemCrossReference."Reference No.");
    end;

    procedure FindSalesCrossRef(var SalesLine: Record "Sales Line"): Text[50]
    var
        ItemCrossReference: Record "Item Reference";
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit('');

        ItemCrossReference.RESET();
        ItemCrossReference.SETRANGE("Item No.", SalesLine."No.");
        ItemCrossReference.SETRANGE("Variant Code", SalesLine."Variant Code");
        ItemCrossReference.SETRANGE("Unit of Measure", SalesLine."Unit of Measure Code");
        ItemCrossReference.SETRANGE("Reference Type", ItemCrossReference."Reference Type"::Customer);
        ItemCrossReference.SETRANGE("Reference Type No.", SalesLine."Sell-to Customer No.");
        if ItemCrossReference.FINDFIRST() then
            exit(ItemCrossReference."Reference No.");
    end;

    procedure GetUOMCode(UOMCode: Code[10]): Code[10]
    var
        CodeMapping: Record "PRG_E-Invoice Code Mapping";
    begin
        if UOMCode <> '' then begin

            CodeMapping.GET(CodeMapping.Type::UOM, UOMCode);
            CodeMapping.TESTFIELD("Destination Code");
            exit(CopyStr(CodeMapping."Destination Code", 1, 10));

        end else begin

            if not GetInvSetup() then
                ERROR(Text004);

            CodeMapping.GET(CodeMapping.Type::UOM, '');
            CodeMapping.TESTFIELD("Destination Code");
            exit(CopyStr(CodeMapping."Destination Code", 1, 10));
        end;
    end;

    procedure FillCVInfoForExport(var SalesHeader: Record "Sales Header"): Boolean
    var
        EInvTaxTypeCode: Record "PRG_E-Invoice Tax Type Code";
    begin
        Cust.GET(SalesHeader."Bill-to Customer No.");
        Cust.TestField("VAT Registration No.");

        GlobCVInfo.INIT();
        GlobCVInfo."CV Type" := GlobCVInfo."CV Type"::Customer;
        GlobCVInfo."CV No." := Cust."No.";
        GlobCVInfo."CV Name" := Cust.Name;
        SplitCVName(GlobCVInfo);

        EInvTaxTypeCode.Get(FindSalesLineTaxTypeCode(SalesHeader));
        case EInvTaxTypeCode."PRG_Discharge Integration Type" of
            EInvTaxTypeCode."PRG_Discharge Integration Type"::EArchive:
                begin
                    GlobCVInfo."Integration Type" := GlobCVInfo."Integration Type"::EArchive;
                end;
            EInvTaxTypeCode."PRG_Discharge Integration Type"::EInvoice:
                begin
                    GlobCVInfo."Integration Type" := GlobCVInfo."Integration Type"::EInvoice;
                end;
            EInvTaxTypeCode."PRG_Discharge Integration Type"::" ":
                begin
                    if Cust.PRG_Alias = '' then
                        GlobCVInfo."Integration Type" := GlobCVInfo."Integration Type"::EArchive
                    else
                        GlobCVInfo."Integration Type" := GlobCVInfo."Integration Type"::EInvoice;
                end;
        end;

        GlobCVInfo."Profile ID" := GlobCVInfo."Profile ID"::IHRACAT;
        GlobCVInfo."E-mail Address" := Cust."E-Mail";
        GlobCVInfo."E-Invoice Starting Date" := ExportSetup."E-Export Starting Date";
        GlobCVInfo."Tax Registration No." := Cust."VAT Registration No.";
        if (Cust."Country/Region Code" = ExportSetup."Company Country/Region Code") or (Cust."Country/Region Code" = '') then
            GlobCVInfo."Tax Registration No." := Cust."VAT Registration No.";
    end;

    local procedure FindSalesLineTaxTypeCode(var SalesHeader: Record "Sales Header"): Code[20]
    var
        SalesLine: Record "Sales Line";
        TaxTypeCode: Code[20];
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter(Type, '%1|%2', SalesLine.Type::Item, SalesLine.Type::"G/L Account");
        SalesLine.SetFilter("PRG_E-Invoice Tax Type Code", '<>%1', '');
        SalesLine.FindFirst();

        TaxTypeCode := SalesLine."PRG_E-Invoice Tax Type Code";

        SalesLine.SetFilter("PRG_E-Invoice Tax Type Code", '<>%1', TaxTypeCode);
        if SalesLine.FindFirst() then
            Error(Text012);

        exit(TaxTypeCode);
    end;

    procedure GetExportSetup(): Boolean
    begin
        if not GotExportSetup then begin
            ExportSetup.get();
            GotExportSetup := true;
        end;
    end;

    procedure GetInvSetup(): Boolean
    begin
        if not GotInvSetup then begin
            if not EInvSetup.get() then
                exit(false);
            GotInvSetup := true;
        end;
        exit(true);
    end;

    local procedure SplitCVName(var TempCVInfo: Record "PRG_E-Invoice CV Info.")
    var
        i: Integer;
        Pos: Integer;
    begin
        if TempCVInfo."CV Name" = '' then
            exit;

        TempCVInfo."CV Name" := DELCHR(TempCVInfo."CV Name", '><');

        if STRPOS(TempCVInfo."CV Name", ' ') = 0 then
            exit;

        for i := 1 to STRLEN(TempCVInfo."CV Name") do
            if COPYSTR(TempCVInfo."CV Name", i, 1) = ' ' then
                Pos := i;

        TempCVInfo."First Name" := COPYSTR(TempCVInfo."CV Name", 1, Pos - 1);
        TempCVInfo."Family Name" := COPYSTR(TempCVInfo."CV Name", Pos + 1);
    end;

    local procedure CalcSalesInvDiscAmt(SalesHeader: Record "Sales Header") InvDiscAmount: Decimal
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SETRANGE("Document No.", SalesHeader."No.");
        if SalesLine.FINDSET() then
            repeat
                if SalesHeader."Prices Including VAT" then
                    InvDiscAmount := InvDiscAmount + (SalesLine."Inv. Discount Amount" + SalesLine."Line Discount Amount")
                      / (1 + SalesLine."VAT %" / 100)
                else
                    InvDiscAmount := InvDiscAmount + (SalesLine."Inv. Discount Amount" + SalesLine."Line Discount Amount");
            until SalesLine.NEXT() = 0;

        exit(InvDiscAmount);
    end;

    procedure GetSourceDesc(pType: Option; pNo: Code[20]): Text[100]
    var
        FA: Record "Fixed Asset";
        GLAcc: Record "G/L Account";
        Item: Record "Item";
        Res: Record "Resource";
        SalesLine: Record "Sales Invoice Line";
    begin
        case pType of
            SalesLine.Type::Item.AsInteger():
                begin
                    Item.GET(pNo);
                    exit(Item.Description);
                end;
            SalesLine.Type::"G/L Account".AsInteger():
                begin
                    GLAcc.GET(pNo);
                    exit(GLAcc.Name);
                end;
            SalesLine.Type::Resource.AsInteger():
                begin
                    Res.GET(pNo);
                    exit(Res.Name);
                end;
            SalesLine.Type::"Fixed Asset".AsInteger():
                begin
                    FA.GET(pNo);
                    exit(FA.Description);
                end;
        end;

        exit('');
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeInsertInvoiceLine(var EInvHeader: Record "PRG_E-Invoice Header"; var SalesLine: Record "Sales Line"; var ItemName: Text; var Description: Text)
    begin
    end;
}