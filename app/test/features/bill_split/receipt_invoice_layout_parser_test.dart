import 'package:airo_app/features/bill_split/domain/services/receipt_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses invoice layout with separated item and total columns', () {
    final parser = MLKitReceiptParserService();

    final receipt = parser.parseRecognizedTextForTesting(_urbanCompanyOcrText);

    expect(receipt.vendor, 'Urban Company');
    expect(receipt.orderId, '260010284981');
    expect(receipt.items, hasLength(1));
    expect(receipt.items.single.name, 'Convenience and Platform Fee - Plumber');
    expect(receipt.items.single.totalPricePaise, 900);
    expect(receipt.grandTotalPaise, 900);
  });
}

const _urbanCompanyOcrText = '''
Urban
Company
Urban Company Limited (Formerly known as
Urbanclap Technologies India Limited and
Urbanclap Technologies India Private Limited)
Registered Office
Unit No. O08, Ground Floor, Rectangle 1, D4,
Saket District Centre
New Delhi. Delhi. India - 110017
Email: help@urbancompany.com
Telephone: +911244570250
CIN L74140DL2014PLC274413
www.urbancompany.com
Customer Name
Uday Chauhan
Invoice no.
UCIC260010284981
Delivery Address
A-301 Savoir Flair, Laxman nagar lane no
7, Lane Number 7, Laxman Nagar, Baner,
Pune, Maharashtra 411045, India,
balewadi baner
Invoice Date
15 Jun, 2026
State Name & Code
Maharashtra 27
Place of Supply
Maharashtra 27
Items
Convenience and Platform Fee - Plumber
SAC: 999799
TOTAL AMOUNT
*Reverse Charge mechanism not applicable
Gross Amount
Discount
Taxable Value
IGST @18%
DELIVERY SERVICE PROVIDER
Business GSTIN
06AABCU7755Q1ZK
Business Name
TAX INVOICE
Urban Company Limited (Formerly known
as Urbanclap Technologies India Limited
and Urbanclap Technologies India Private
Limited)
Address
7TH and 8TH Floor, Plot No 183, Udyog
Vihar
Sector 20, Rajiv Nagar, Gurugram,
Haryana - 122016
State Name & Code
Haryana 06
Taxable Value
Rs. 27.63
- Rs. 20
Rs. 7.63
(seven point six three
only)
Rs. 1.37
(one point three seven
only)
Rs. 9
aper
Signature of supplier/authorized representative
''';
