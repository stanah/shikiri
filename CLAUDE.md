# Claude Code Instructions

## Task Master AI Instructions
**Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**
@./.taskmaster/CLAUDE.md

## Shikiri 開発メモ

### macOS権限関連の重要な知識

#### 1. CGEventTap の権限要件
- **`listenOnly` オプション** → **Input Monitoring（入力監視）権限**が必要
- **`defaultTap` オプション** → **Accessibility（アクセシビリティ）権限**が必要
- 参考: https://developer.apple.com/forums/thread/122492

#### 2. Input Monitoring権限の確認・リクエスト
```swift
// 権限確認
let hasAccess = CGPreflightListenEventAccess()

// 権限リクエスト（ダイアログ表示）
let granted = CGRequestListenEventAccess()
```

#### 3. 開発中の権限維持
- **問題**: ビルドするたびに署名が変わり、毎回権限許可が必要になる
- **解決**: Xcodeで開発チームを設定し、正規の署名証明書を使用する
  1. Xcode → Settings → Accounts でApple IDにサインイン
  2. プロジェクトの Signing & Capabilities でTeamを選択
  3. `xcodebuild` 実行時に以下のオプションを指定:
     ```bash
     xcodebuild -scheme Shikiri \
         CODE_SIGN_IDENTITY="Apple Development" \
         DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
         CODE_SIGN_STYLE="Automatic" \
         -allowProvisioningUpdates \
         build
     ```

#### 4. MenuBarExtra アプリの初期化タイミング
- **問題**: `MenuBarExtra` 内の `ContentView.onAppear` はメニューをクリックするまで呼ばれない
- **解決**: シングルトンパターンの `AppController` を使用し、`Task` で非同期に初期化を実行

### ビルド & 実行
```bash
./run-debug.sh
```

### ログ確認
```bash
tail -f /tmp/shikiri_app.log
```

### 必要な権限
1. **アクセシビリティ** - ウィンドウ操作に必要
2. **入力監視** - CGEventTap (listenOnly) に必要
