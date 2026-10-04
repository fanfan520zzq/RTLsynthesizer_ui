# EC11 三页 UI 测试构建记录

日期：2026-10-01。版本：`0.2.1-ec11-native-font-test`。
原始验证目录：`D:\fpga\gowin_fpga_prj\60k_ui_prj`。本文件保留迁入前的历史构建证据，本次发布复核见 `../docs/UI_ONLY_RELEASE.md`。
目标：Tang Mega 60K，GW5AT-LV60PG484AC1/I0，800×480。

## 已完成

- ModelSim 10.3c：`tools/test_ec11.ps1` 六项通过，编译 0 Error / 0 Warning。
  - `tb_panel_pll`：使用 Gowin GW5A PLLA 模型，像素周期 30 ns、串行周期 6 ns。
  - `tb_panel_timing`：两帧完整扫描，每帧 384000 可见像素 / 554400 总像素。
  - `tb_ec11_controls`：三页焦点/首尾循环、按钮请求、七个音色、四个参数限幅与确认、
    长按取消、抑制长按后的误短按、切页保留状态。
  - `tb_ec11_input`：真实 A/B/SW 信号经过原解码器进入控制器，验证短脉冲消抖、
    正反向旋转、短按切页、参数调节、长按恢复。
  - `tb_ec11_font`：95 个可打印 ASCII 的全部 1520 行、同步 ROM 延迟、空白字符及位序。
  - `tb_ec11_scene`：页面像素、帧锁存、高亮、编辑颜色、动态条形填充和十六进制字形；
    对完整 8×16 正文字格及 16×32 大字逐像素核对，保证横纵等比例、没有单轴拉伸。
- `tools/render_ec11.ps1`：`tb_ec11_render` 三页完整 RGB 输出通过，0 Error / 0 Warning；
  转换为 `preview/ec11_page_0.png`、`ec11_page_1.png`、`ec11_page_2.png`，均为 800×480。
  已目视检查最终像素图：原生 8×16 正文字格、等比例 16×32 大字，无文字截断，曲目选中框不覆盖文字，
  编辑框/音色选中框/页面内容正确。这是 RTL 渲染证据，不是实板屏幕照片。
- Gowin V1.9.11.03 Education：综合、布局布线、位流生成完成。
  - Logic：2689 / 59904，其中 LUT 2582、ALU 107；无 Latch。
  - Register：338 / 60780。
  - DSP：2 / 118，内部为 4 个 MULT12X12；BSRAM：1 / 118，用于共用的 2048×8 字体 pROM。
  - 像素约束 33.333 MHz，报告 Fmax 64.166 MHz。
  - Setup/Hold violated endpoints：0 / 0；最差列出 Setup slack 14.416 ns。
  - P&R 管脚确认：EC11 A15/B20/B21，时钟 V22，复位 Y12，HDMI 管脚未变。

## 位流身份

文件：`impl/pnr/fpga_ui_60k_ec11.fs`。

```text
SHA256 AFB7D82227FB53D04E723D3CAAA4B9E01B1EDBA1B1BE0CD84638A96DE355B64A
```

布局源 SHA256：`a5822872b8aa39503b1e7a382e2d5b8d71a31ed9aa6d6fb7dbc2974afecdf51e`。
新字体快照 SHA256：`092d4d0395970dd3f0d6b8eaeedf2e114265ee4bcbb28e1c06095181593003f2`。
复制的 `ec11_decoder.v` 与已验证例程逐字节相同，SHA256：
`5285C1EBF7C55628EE58CDE180ACB964312356097D018A3A5B73B300DA0A35DB`。
800×480 PLL、时序控制器、SDC 与显示成功的 monorepo 工程对应文件相同；
加密 DVI_TX_Top IP 也相同，没有替换为 Nano20K 或 138K PHY。

## 保留提示与未验证项

- Gowin 保留 DVI IP 内部 `clk_d` 通用时钟路由警告 PR1014，沿用官方 60K DVI 时钟分组。
  Setup/Hold 0/0 只说明当前约束覆盖的路径，不代表 TMDS 电气、所有跨时钟路径已仿真。
- 生成器字模行/列取低位及计数器常量宽度存在 EX3791 截断提示，字形与扫描边界已经测试。
- 初次 ROM 初始化循环超过 Gowin 的 2000 次展开限制，已拆为 1024 次循环分别初始化两半。
  修正后重新编译仿真及全流程构建完成，最终位流不是失败构建遗留的旧文件。
- 新字体位流尚未实板验证，用户还需重新烧录检查；旧版屏幕字体反馈不能替代新版验收。
- 没有 SD 文件系统、音频、串口或 Dimension ACK；本地请求不是 UART 命令，也不发出 ACK。
- 旧实板基线目录没有修改。本次没有提交/推送 Git。
