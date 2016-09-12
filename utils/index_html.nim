#? stdtmpl
#
#import strutils, ospaths
#
#proc index_html*(files: seq[(string, seq[string])]): string =
#  result = ""
<!doctype html>
<html lang="en">
    <head>
        <meta charset="UTF-8"/>
        <title>nimboost library documentation</title>
        <link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons">
        <link rel="stylesheet" href="https://code.getmdl.io/1.2.1/material.blue-indigo.min.css" />
        <script defer src="https://code.getmdl.io/1.2.1/material.min.js"></script>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"> 
        <style>
           html, body {
             font-family: 'Roboto', 'Helvetica', sans-serif;
             margin: 0;
             padding: 0;
           } 
        </style>
    </head>
    <body>
        <div class="content">
            <div class="mdl-layout mdl-js-layout">
                <header class="mdl-layout__header">
                    <div class="mdl-layout__header-row">
                        <div class="mdl-layout-icon"></div>
                        <span class="mdl-layout__title">The nimboost library documentation</span>
                        <div class="mdl-layout-spacer"></div>
                        <nav class="mdl-navigation">
                            # for v in files:
                                <a class="mdl-navigation__link" href="#${v[0]}">Version ${v[0]}</a>
                            # end for
                        </nav>
                    </div>
                </header>
                <main class="mdl-layout__content">
                    # for v in files:
                      <div class="mdl-grid">
                          <div class="mdl-cell mdl-cell--12-col"><h6 id="${v[0]}">Version ${v[0]}</h6>
                              <ul>
                              # for f in v[1]:
                                  <li><a href="${"docs" / v[0] / f}">${f.replace("/", ".").splitFile[1]}</a></li>
                              # end for
                              </ul>
                          </div>
                      </div>
                    # end for
                </main>
            </div>
        </div>
    </body>
</html>
