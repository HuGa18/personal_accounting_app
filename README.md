# 个人全渠道记账应用

完全本地化运行的移动应用，支持导入支付宝、微信支付、银行卡等多平台账单。

## 技术栈

- **Flutter**: 3.x
- **Riverpod**: 2.x (状态管理)
- **SQLite**: 2.x (本地存储)
- **fl_chart**: 0.63.x (图表可视化)

## 项目结构

```
personal_accounting_app/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── models/                   # 数据模型
│   │   ├── account.dart          # 账户模型
│   │   ├── transaction.dart      # 交易模型
│   │   ├── category.dart         # 分类模型
│   │   └── budget.dart           # 预算模型
│   ├── repositories/             # 数据仓库
│   │   ├── account_repository.dart
│   │   ├── transaction_repository.dart
│   │   └── category_repository.dart
│   ├── database/                 # 数据库
│   │   └── db.dart               # 数据库初始化
│   └── ...
├── pubspec.yaml                  # 依赖配置
└── README.md
```

## 使用方法

### 1. 安装Flutter SDK

访问 https://flutter.dev/docs/get-started/install

### 2. 安装依赖

```bash
cd personal_accounting_app
flutter pub get
```

### 3. 运行应用

```bash
flutter run
```

### 4. 构建APK

```bash
flutter build apk --release
```

## 功能特性

- ✅ 多渠道账单导入（支付宝、微信、银行卡等）
- ✅ 智能分类引擎（自动匹配商户分类）
- ✅ 本地SQLite存储（数据完全私密）
- ✅ 财务统计分析（图表可视化）
- ✅ 预算管理
- ✅ 数据导出分享

## 数据库表结构

- **accounts**: 账户表
- **transactions**: 交易记录表
- **categories**: 分类表
- **budgets**: 预算表

## 注意事项

1. 数据完全存储在本地，不上传云端
2. 所有功能无需联网即可使用
3. 用户完全掌控自己的财务数据
4. 支持iOS和Android双平台