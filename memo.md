# 用語

すべて独自解釈

-   ROBJ
    -   ルートオブジェクト。恐らくコアインスタンスで、この上に全部乗っている
    -   lib/Satsuki/Base.pm が本体
    -   `$ROBJ->start_up();`はここにいる
-   lib/SatsukiApp/adiary.pm::main
    -   `$ROBJ->start_up();`が蹴られた後にセットアップ済みなら、恐らくここが呼ばれる
-   テンプレートファイルへの変数埋め込み
    -   adiary.pm の self にプロパティを生やせば行けると思う。恐らく
