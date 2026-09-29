# Swift LLM 輸出驗證範例

這是從個人 SwiftUI 專案 **Moment** 的 LLM 提案驗證設計整理出的獨立 Swift Package，
不是完整 App 的原始碼匯出。Moment 本身仍是私有、開發中的專案。

[English](README.md)

## 核心問題

合法 JSON 不一定是合法產品資料。模型可以建議「選蛋糕」，但不能在執行結果欄位
填入「蛋糕已訂好」，把建議冒充已完成的事實。

範例限定兩種內容：行動清單與邀請函草稿。流程依序做大小檢查、封閉型別解碼、
版本／產品規則驗證，最後才回傳 `ValidatedTaskModelProposal`。
這個值只代表「可以交給使用者檢視」，不代表已確認、已儲存或已執行。

## 執行

需要 Swift 6.0 以上，沒有外部 package 相依或模型金鑰。

```sh
git clone https://github.com/timyeou1234/swift-llm-output-validation.git
cd swift-llm-output-validation
swift build -c release
swift test --enable-code-coverage
swift test -c release
bash scripts/check-examples.sh
```

也可以分別執行：

```sh
swift run proposal-demo Examples/checklist.json
swift run proposal-demo Examples/invitation.json
swift run proposal-demo Examples/invalid-outcome.json
```

最後一份範例刻意預填執行結果，因此應回報 `Rejected: invalidCandidate`，exit code 為 1。

## 閱讀重點

`Sources/MomentLLMValidation/ProposalValidation.swift` 包含不可變的資料型別、
未知欄位拒絕、產品驗證及無公開 initializer 的已驗證結果型別。
`Tests/MomentLLMValidationTests/ProposalValidationTests.swift` 有 34 項 XCTest，
不靠真實 LLM 或網路即可驗證正常與異常情境。

產品規則涵蓋 schema 版本、成果數量、ID／順序、成果類型與 renderer 的相容性、
欄位角色／型別，以及候選內容的字數、清單與填入權限。

GitHub Actions 已配置 Linux／macOS 的 build、Debug／Release tests 與三個 demo 範例檢查。
遠端執行狀態以實際 Actions 紀錄為準，本機驗證記錄見 `docs/VERIFICATION.md`。

## 範圍限制

不包含 UI、實際模型呼叫、資料庫、工具執行或完整使用者確認流程。
不宣稱能驗證文字真偽、防住所有 prompt injection，或偵測原始 JSON 中的重複鍵名。
內附 JSON Schema 是結構文件，產品的交叉欄位限制仍由 Swift 驗證。

不含前公司程式碼、金鑰或真實客戶資料。私有 Moment Repo 不需要改為公開；
公開的是這份獨立示範。尚未選擇開源授權，詳見 `NOTICE.md`。
