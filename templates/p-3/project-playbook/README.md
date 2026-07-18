# PROJECT-PLAYBOOK

## Index

1. Summary
2. Document Templates
    1. PRD
    2. Design Doc
      1. System Design Doc
      2. Feature Design Doc
    3. Dev Setup
    4. Deployment Procedure
    5. Operation Runbook

## 1. Summary
このProject Playbookは、5〜10人規模の開発プロジェクトで最低限必要なドキュメントをテンプレート化したものです。

### 使い方
- 新規プロジェクト開始時: PRD → System Design Doc → Dev Setup → Deployment Procedure → Operation Runbook の順に作成
- 機能追加・改修時: Feature Design Doc を作成
- 各テンプレートは「最低限これだけは」という項目に絞っています。不要な項目は削除してOK

### 原則
- ドキュメントは軽量に（各1〜5ページ目標）
- プロジェクトキックオフ時にドキュメント作成時間を明示的にスケジュール
- README.mdに各ドキュメントへのリンクをまとめる

## 2. Document Templates

### 2-1. PRD
**目的**: 何を作るか、なぜ作るかを明確にする

プロジェクトの概要/背景と目的
ターゲットユーザーと課題
主要機能（ユーザーストーリー）
成功指標（KPI）
スコープ外の項目

### 2-2. Design Doc (Technical Design Document)

#### 2-2-1. System Design Doc

Goal/Non-Goal

アーキテクチャ概要、技術選定理由、主要な設計判断
技術選定と判断理由（ADR:Architectural Decision Records 含む）
ルーティング（画面の定義はdesign-specが所有）
API設計
データモデル
セキュリティ・パフォーマンス考慮事項
テスト戦略（どのレイヤーを何でテストするか）、テストカバレッジの目標、テスト自動化の方針
モニタリング・ログ設計

#### 2-2-2. Feature Design Doc
**作成基準**: 原則、1ユーザーストーリー = 1 Feature Design Doc（小さな改善は複数まとめてOK、大きなストーリーは分割してもOK）
背景と目的（なぜこの変更が必要か）
Goal/Non-Goal
影響範囲
実装アプローチ/トレードオフ
詳細設計
API変更/UI変更（あれば）
データマイグレーション計画
テスト方針
ロールアウト計画/リリース計画

### 2-3. Dev Setup
環境構築手順（30分以内を目標）
必要なツール・アカウント
ローカル開発サーバーの起動方法
テストの実行方法
タスク管理ツール
チケット起票ルール
ブランチ戦略
PRの出し方/レビュープロセス
よくあるトラブルシューティング

### 2-4. Deployment Procedure
各環境（開発・ステージング・本番）へのデプロイ手順
リリース前チェックリスト
ロールバック手順
デプロイ後の確認項目
緊急時の連絡先

### 2-5. Operation Runbook
モニタリング・ログ設計（何を記録するか、保持期間、ログレベル）
監視ポイントとアラート設定
よくある障害とその対処法
ログの確認方法
エスカレーションフロー
定期メンテナンス作業
