Function GetMarketPrices(tickersString)
    Dim tickers, prices()
    Dim i, xlApp, xlBook, result
    
    ' Split input string into array
    tickers = Split(tickersString, ";")
    
    ' Initialize output array
    ReDim prices(UBound(tickers))
    
    ' Connect to Excel + Capital IQ
    Set xlApp = CreateObject("Excel.Application")
    xlApp.Visible = False
    Set xlBook = xlApp.Workbooks.Add()
    WScript.Sleep 3000  ' Wait for plugin to load
    
    ' Fetch prices
    For i = 0 To UBound(tickers)
        prices(i) = GetPrice(xlApp, Trim(tickers(i)))  ' Trim to remove whitespace
    Next
    
    ' Convert prices array to semicolon string
    result = Join(prices, ";")
    
    ' Cleanup
    xlBook.Close False
    xlApp.Quit
    Set xlBook = Nothing
    Set xlApp = Nothing
    
    GetMarketPrices = result
End Function

Function GetPrice(xlApp, ticker)
    Dim price
    On Error Resume Next
    price = xlApp.Evaluate("=SPG(""" & ticker & """,""SP_LASTSALEPRICE"")")
    If Err.Number <> 0 Or Not IsNumeric(price) Then price = 0
    On Error GoTo 0
    GetPrice = price
End Function
