xquery version "3.1";

declare namespace ti="http://chs.harvard.edu/xmlns/cts";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare option output:method "html5";
declare option output:media-type "text/html";
declare option output:indent "yes";

let $urn := normalize-space(request:get-parameter("urn", ""))
let $requestedRef := normalize-space(request:get-parameter("ref", ""))
let $dataRoots := (
    "/db/apps/canonical-greekLit/data",
    "/db/canonical-greekLit/data",
    "/db/data"
)
let $dataRoot := (for $root in $dataRoots where xmldb:collection-available($root) return $root)[1]
let $textgroups :=
    if ($dataRoot) then
        collection($dataRoot)//ti:textgroup
    else
        ()
let $textInventory :=
    for $tg in $textgroups
    let $authorId := tokenize(string($tg/@urn), ":")[last()]
    let $authorName := string(($tg/ti:groupname[@xml:lang = "eng"], $tg/ti:groupname)[1])
    let $worksPath := concat($dataRoot, "/", $authorId)
    let $works :=
        if (xmldb:collection-available($worksPath)) then
            collection($worksPath)//ti:work
        else
            ()
    order by lower-case($authorName)
    return
        map {
            "author-id": $authorId,
            "author-name": $authorName,
            "works":
                for $work in $works
                let $workUrn := string($work/@urn)
                let $workTitle := string(($work/ti:title[@xml:lang = "eng"], $work/ti:title)[1])
                let $texts :=
                    for $text in ($work/ti:edition, $work/ti:translation)
                    let $textUrn := string($text/@urn)
                    let $textId := replace(tokenize($textUrn, ":")[last()], "^greekLit:", "")
                    let $textRelPath := concat($authorId, "/", tokenize($workUrn, "\\.")[2], "/", $textId, ".xml")
                    let $textPath := concat($dataRoot, "/", $textRelPath)
                    let $label := string(($text/ti:label[@xml:lang = "eng"], $text/ti:label)[1])
                    let $lang := string($text/@xml:lang)
                    where doc-available($textPath)
                    order by $lang, lower-case($label)
                    return map {
                        "urn": $textUrn,
                        "label": $label,
                        "lang": $lang,
                        "path": $textPath
                    }
                order by lower-case($workTitle)
                return map {
                    "urn": $workUrn,
                    "title": $workTitle,
                    "texts": $texts
                }
        }

let $selectedText :=
    if ($urn = "") then
        ()
    else
        head(
            for $author in $textInventory
            for $work in $author?works
            for $text in $work?texts
            where $text?urn = $urn
            return map {
                "author": $author,
                "work": $work,
                "text": $text
            }
        )

let $textDoc :=
    if (exists($selectedText)) then
        doc($selectedText?text?path)
    else
        ()

let $sections :=
    if (exists($textDoc)) then
        for $chapter in $textDoc//tei:div[@type = "textpart"][@subtype = "chapter"]
        let $chapterN := string($chapter/@n)
        for $section in $chapter/tei:div[@type = "textpart"][@subtype = "section"]
        let $sectionN := string($section/@n)
        let $ref := concat($chapterN, ".", $sectionN)
        return map {
            "ref": $ref,
            "node": $section
        }
    else
        ()

let $activeRef :=
    if ($requestedRef != "" and some $s in $sections satisfies $s?ref = $requestedRef) then
        $requestedRef
    else if (exists($sections)) then
        $sections[1]?ref
    else
        ""

let $activeIndex :=
    if ($activeRef = "") then
        0
    else
        index-of($sections! ?ref, $activeRef)[1]

let $activeSection :=
    if ($activeIndex gt 0) then
        $sections[$activeIndex]
    else
        ()

let $prevRef :=
    if ($activeIndex gt 1) then
        $sections[$activeIndex - 1]?ref
    else
        ""

let $nextRef :=
    if ($activeIndex gt 0 and $activeIndex lt count($sections)) then
        $sections[$activeIndex + 1]?ref
    else
        ""

return
<html lang="en">
    <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>Canonical Greek Literature — Simple Reader</title>
        <style>
            :root {{
                --bg: #f8f9fb;
                --surface: #ffffff;
                --text: #1c2430;
                --muted: #526074;
                --border: #d8dee8;
                --brand: #3151b7;
            }}
            * {{ box-sizing: border-box; }}
            body {{
                margin: 0;
                font-family: "Inter", "Segoe UI", system-ui, sans-serif;
                color: var(--text);
                background: var(--bg);
            }}
            .layout {{
                display: grid;
                grid-template-columns: minmax(280px, 360px) 1fr;
                min-height: 100vh;
            }}
            aside {{
                background: var(--surface);
                border-right: 1px solid var(--border);
                padding: 1rem;
                overflow-y: auto;
            }}
            main {{
                padding: 1.5rem;
                max-width: 980px;
            }}
            h1 {{ margin-top: 0; font-size: 1.3rem; }}
            h2 {{ margin: 0.5rem 0; font-size: 1.05rem; }}
            h3 {{ margin: 0.3rem 0; font-size: 0.95rem; color: var(--muted); }}
            .author {{ margin: 0 0 1.2rem; }}
            .work {{ margin: 0 0 0.6rem 0.6rem; }}
            ul {{ margin: 0.2rem 0 0.75rem 1.2rem; padding: 0; }}
            li {{ margin: 0.25rem 0; }}
            a {{ color: var(--brand); text-decoration: none; }}
            a:hover {{ text-decoration: underline; }}
            .active {{ font-weight: 700; }}
            .muted {{ color: var(--muted); }}
            .card {{
                background: var(--surface);
                border: 1px solid var(--border);
                border-radius: 10px;
                padding: 1rem 1.2rem;
                box-shadow: 0 1px 1px rgba(0,0,0,0.03);
            }}
            .controls {{ display: flex; gap: 0.75rem; margin: 1rem 0; }}
            .btn {{
                border: 1px solid var(--border);
                background: white;
                border-radius: 8px;
                padding: 0.45rem 0.75rem;
                font-size: 0.92rem;
            }}
            .btn.disabled {{ opacity: 0.45; pointer-events: none; }}
            p {{ line-height: 1.65; }}
            @media (max-width: 900px) {{
                .layout {{ grid-template-columns: 1fr; }}
                aside {{ border-right: none; border-bottom: 1px solid var(--border); max-height: 45vh; }}
                main {{ max-width: none; }}
            }}
        </style>
    </head>
    <body>
        <div class="layout">
            <aside>
                <h1>Canonical Greek Literature</h1>
                <p class="muted">Simple author index + section reader.</p>
                {
                    if (empty($textInventory)) then
                        <p class="muted">No text inventory was found. Confirm the package is installed in eXist-db.</p>
                    else
                        for $author in $textInventory
                        return
                            <section class="author">
                                <h2>{$author?author-name}</h2>
                                {
                                    for $work in $author?works
                                    return
                                        <div class="work">
                                            <h3>{$work?title}</h3>
                                            <ul>
                                                {
                                                    for $text in $work?texts
                                                    let $isActive := exists($selectedText) and $text?urn = $selectedText?text?urn
                                                    let $textName := concat($text?label, " (", upper-case($text?lang), ")")
                                                    return
                                                        <li>
                                                            <a class="{if ($isActive) then 'active' else ''}" href="?urn={$text?urn}">{$textName}</a>
                                                        </li>
                                                }
                                            </ul>
                                        </div>
                                }
                            </section>
                }
            </aside>
            <main>
                {
                    if (empty($selectedText)) then
                        <div class="card">
                            <h2>Select a text from the index</h2>
                            <p class="muted">Pick any edition or translation from the left sidebar to begin reading.</p>
                        </div>
                    else
                        (
                            <div class="card">
                                <h2>{$selectedText?author?author-name} — {$selectedText?work?title}</h2>
                                <p class="muted">{$selectedText?text?label} ({upper-case($selectedText?text?lang)})</p>
                                {
                                    if (empty($sections)) then
                                        <p class="muted">No section-level references were found for this text.</p>
                                    else
                                        (
                                            <p><strong>Section {$activeRef}</strong> ({$activeIndex} of {count($sections)})</p>,
                                            <div class="controls">
                                                {
                                                    if ($prevRef != "") then
                                                        <a class="btn" href="?urn={$selectedText?text?urn}&amp;ref={$prevRef}">← Previous</a>
                                                    else
                                                        <span class="btn disabled">← Previous</span>
                                                }
                                                {
                                                    if ($nextRef != "") then
                                                        <a class="btn" href="?urn={$selectedText?text?urn}&amp;ref={$nextRef}">Next →</a>
                                                    else
                                                        <span class="btn disabled">Next →</span>
                                                }
                                            </div>,
                                            for $p in $activeSection?node//tei:p
                                            return <p>{normalize-space(string-join($p//text(), " "))}</p>
                                        )
                                }
                            </div>
                        )
                }
            </main>
        </div>
    </body>
</html>
