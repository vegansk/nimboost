import boost.http.httpcommon, boost.data.props, unittest, strtabs, sequtils

suite "HTTP utils":
  test "URL encode/decode":
    check: "Hello, world!".urlEncode == "Hello%2C+world%21"
    check: "Hello%2C+world%21".urlDecode == "Hello, world!"
    check: "Привет, мир!".urlEncode == "%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82%2C+%D0%BC%D0%B8%D1%80%21"
    check: "%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82%2C+%D0%BC%D0%B8%D1%80%21".urlDecode == "Привет, мир!"
    check: "!@#$%^&*()_+".urlEncode == "%21%40%23%24%25%5E%26%2A%28%29_%2B" 
    check: "%21%40%23%24%25%5E%26%2A%28%29_%2B".urlDecode == "!@#$%^&*()_+"

  test "x-www-form-urlencoded encode/decode":
    var f = newProps({"Name": "Jonathan Doe", "Age": "23", "Formula": "a + b == 13 %!"})
    let s = "Name=Jonathan+Doe&Age=23&Formula=a+%2B+b+%3D%3D+13+%25%21"
    check: f.formEncode == s
    f = s.formDecode
    check: f["Name"] == "Jonathan Doe"
    check: f["Age"] == "23"
    check: f["Formula"] == "a + b == 13 %!"
