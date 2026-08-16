# PROJECT-PLAYBOOK

開発着手に必要なドキュメントのテンプレート一式。DRAFTのPhase 3（/draft:playbook、または手動フロー）がこれを元に docs/ を生成する。

**方法論の正は [DRAFTのREADME](../../README.md)。** いつ何を書くか・事実の所有権・変更サイクル・省略の裁量は全てそちらが定める。このファイルはテンプレートの一覧だけを持つ（内容をここに再掲すると、本則と食い違ったまま配布される）。

| テンプレート | 内容 |
|-------------|------|
| [templates/01_prd.md](templates/01_prd.md) | 概要/背景と目的、ターゲットユーザーと課題、主要機能（ユーザーストーリー）、成功指標（KPI）、スコープ外 |
| [templates/02-01_system-design-doc.md](templates/02-01_system-design-doc.md) | Goal/Non-Goal、アーキテクチャ、技術選定（ADR）、ルーティング、API設計、データモデル、セキュリティ、エラーハンドリング、i18n、テスト戦略、モニタリング |
| [templates/02-02_feature-design-doc.md](templates/02-02_feature-design-doc.md) | 変更サイクルのFDD雛形（背景と目的、Goal/Non-Goal、影響範囲、実装アプローチ、詳細設計、テスト方針、ロールアウト） |
| [templates/03_dev-setup.md](templates/03_dev-setup.md) | 環境構築、コマンド体系（makeターゲット）、ブランチ戦略、リリースフロー、トラブルシューティング |
| [templates/04_deployment-procedure.md](templates/04_deployment-procedure.md) | デプロイ手順、リリース前チェックリスト、ロールバック、デプロイ後確認 |
| [templates/05_operation-runbook.md](templates/05_operation-runbook.md) | モニタリング・ログ、監視とアラート、障害対応、定期メンテナンス |
| [templates/06_design-tokens.json](templates/06_design-tokens.json) | デザイントークン（色・タイポグラフィ・余白・角丸・影・モーションの具体値。DTCG形式、プリミティブ+セマンティックの2層） |

参考資料: [docs/tech-stacks-aws.md](docs/tech-stacks-aws.md) / [docs/tech-stacks-gcp.md](docs/tech-stacks-gcp.md)（技術選定の比較材料）
