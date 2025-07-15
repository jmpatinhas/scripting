Function GetMarketPrices(tickers)
    Dim prices()
    Dim i, xlApp, xlBook
    
    ' Size the output array
    ReDim prices(UBound(tickers))
    
    ' Create single Excel instance
    Set xlApp = CreateObject("Excel.Application")
    xlApp.Visible = False
    xlApp.DisplayAlerts = False
    
    ' Add new workbook (required for plugin to load)
    Set xlBook = xlApp.Workbooks.Add()
    
    ' Wait for plugin to initialize (if needed)
    WScript.Sleep 5000
    
    ' Get price for each ticker
    For i = 0 To UBound(tickers)
        prices(i) = GetPrice(xlApp, tickers(i))
    Next
    
    ' Clean up
    xlBook.Close False
    xlApp.Quit
    Set xlBook = Nothing
    Set xlApp = Nothing
    
    GetMarketPrices = prices
End Function

Function GetPrice(xlApp, ticker)
    Dim price
    
    On Error Resume Next
    
    ' Use Capital IQ formula
    price = xlApp.Evaluate("=SPG(""" & ticker & """,""SP_LASTSALEPRICE"")")
    
    If Not IsNumeric(price) Then 
        price = 0
    End If
    
    On Error GoTo 0
    
    GetPrice = price
End Function
