unit AUTOFOKUS_MIKROSKOP_V2;

interface

uses
  Winapi.Windows,
  Winapi.Messages,

  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Win.Registry,

  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.FileCtrl,
  Vcl.Imaging.pngimage,

  VclTee.TeeGDIPlus,
  VCLTee.TeEngine,
  VCLTee.Series,
  VCLTee.TeeProcs,
  VCLTee.Chart,

  IdTCPClient,
  IdIOHandler,

  CPort,

  ocv.comp.Types,
  ocv.comp.Source,
  ocv.comp.View,
  ocv.comp.ImageOperation, IdBaseComponent, IdComponent, IdTCPConnection;

type
  TPendingMotor = (
    pmNone,
    pmMacro,
    pmMicro
  );

  { Tahapan pengamanan posisi Z sebelum revolver objektif bergerak. }
  TLensChangeState = (
    lcsIdle,
    lcsMoveMicroZero,
    lcsMoveMacroZero,
    lcsMoveObjective,
    lcsSyncZProfile
  );

  TAutoFocusState = (
    afsIdle,
    afsReadyMove,
    afsMoving,
    afsSettling,
    afsSampling,
    afsReadyReturn,
    afsReturning
  );

  TAutoFocusPhase = (
    afpNone,
    afpPrepareMicroCenter,
    afpPrepareWinnerMacro,
    afpMacroScan,
    afpMacroVerify,
    afpMacroReturn,
    afpMicroCoarseScan,
    afpMicroFineScan,
    afpMicroVerify,
    afpMicroBacklashPrep,
    afpMicroReturn
  );

  { Mode pemindaian inti Autofokus. }
  TAutoFocusRunMode = (
    afrmSingleLens,
    afrmMacroOnly,
    afrmMicroOnly
  );

  { Tahapan Autofokus otomatis dua objektif. }
  TDualAutoFocusStage = (
    dafsIdle,
    dafsPreparing4X,
    dafsScanningMacro4X,
    dafsPreparing10X,
    dafsScanningMacro10X,
    dafsSelectingWinner,
    dafsPreparingWinner,
    dafsScanningWinnerMicro,
    dafsCompleted
  );

  TFocusCandidate = record
    Position: Integer;
    Score: Double;
  end;

  TFocusCandidateArray = array[0..2] of TFocusCandidate;

  TfrmMain = class(TForm)
    pnlHeader: TPanel;
    stbMain: TStatusBar;
    pnlBody: TPanel;
    pnlLeft: TPanel;
    pnlRight: TPanel;
    lblRightTitle: TLabel;
    pnlCenter: TPanel;
    pnlBrand: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    scrLeftControl: TScrollBox;

    pnlConnectionCard: TPanel;
    lblConnectionTitle: TLabel;
    lblComPort: TLabel;
    shpConnectionStatus: TShape;
    lblConnectionState: TLabel;
    lblBaudRate: TLabel;
    cmbComPort: TComboBox;
    btnRefreshCom: TButton;
    btnConnect: TButton;

    pnlCameraCard: TPanel;
    lblCameraTitle: TLabel;
    lblSelectCamera: TLabel;
    shpCameraStatus: TShape;
    lblCameraState: TLabel;
    cmbCamera: TComboBox;
    btnCameraSettings: TButton;
    btnStartCamera: TButton;
    btnStopCamera: TButton;

    pnlProcessingCard: TPanel;
    lblProcessingTitle: TLabel;
    rbNormal: TRadioButton;
    rbGrayscale: TRadioButton;
    rbThresholdManual: TRadioButton;
    rbThresholdOtsu: TRadioButton;
    lblThresholdTitle: TLabel;
    lblThresholdValue: TLabel;
    tbThreshold: TTrackBar;
    chkInvertThreshold: TCheckBox;

    pcMainView: TPageControl;
    tabMonitor: TTabSheet;
    tabGraph: TTabSheet;

    pnlPreviewCard: TPanel;
    pnlPreviewHeader: TPanel;
    lblPreviewTitle: TLabel;
    pnlCameraViewHost: TPanel;

    pnlMetricsSection: TPanel;
    pnlMetricPosition: TPanel;
    lblPositionTitle: TLabel;
    lblMacroPositionValue: TLabel;
    lblMicroPositionValue: TLabel;

    pnlMetricOtsu: TPanel;
    lblOtsuTitle: TLabel;
    lblCurrentOtsu: TLabel;
    lblOtsuInfo: TLabel;

    pnlMetricFocus: TPanel;
    lblFocusTitle: TLabel;
    lblCurrentFocus: TLabel;
    lblFocusInfo: TLabel;

    pnlGraphPage: TPanel;
    lblGraphTitle: TLabel;
    pcGraphView: TPageControl;
    tabFocusGraph: TTabSheet;
    tabOtsuGraph: TTabSheet;
    chtFocus: TChart;
    serFocus: TLineSeries;
    chtOtsu: TChart;
    serOtsu: TLineSeries;

    { Komponen grafik Mikrometer dibuat melalui Form Designer/DFM. }
    tabFocusMicroGraph: TTabSheet;
    tabOtsuMicroGraph: TTabSheet;
    chtFocusMicro: TChart;
    serFocusMicro: TLineSeries;
    chtOtsuMicro: TChart;
    serOtsuMicro: TLineSeries;

    pnlManualMotorCard: TPanel;

    lblMacroCurrentTitle: TLabel;
    lblMacroCurrentPosition: TLabel;
    lblMacroTargetTitle: TLabel;
    edtMacroTarget: TEdit;
    btnMoveMacro: TButton;

    edtMicroTarget: TEdit;
    lblMicroTargetTitle: TLabel;
    lblMicroCurrentPosition: TLabel;
    lblMicroCurrentTitle: TLabel;
    btnMoveMicro: TButton;

    pnlAutoFocusCard: TPanel;
    lblAutoFocusTitle: TLabel;
    btnStartAutoFocus: TButton;
    btnStartDualAutoFocus: TButton;
    btnStopAutoFocus: TButton;
    lblScanStageTitle: TLabel;
    lblScanStageValue: TLabel;
    lblScanProgressTitle: TLabel;
    lblScanProgressPercent: TLabel;
    pbAutoFocus: TProgressBar;

    pcRightControl: TPageControl;
    tabManualControl: TTabSheet;
    tabAutoFocusControl: TTabSheet;

    pnlScanResult: TPanel;
    shpResultDivider: TShape;
    lblScanResultTitle: TLabel;
    lblBestMacroTitle: TLabel;
    lblBestMacroValue: TLabel;
    lblBestMicroTitle: TLabel;
    lblBestMicroValue: TLabel;
    lblBestFocusTitle: TLabel;
    lblBestFocusValue: TLabel;

    pnlMacroControl: TPanel;
    lblMacroSectionTitle: TLabel;
    pnlMicroControl: TPanel;
    lblMicroSectionTitle: TLabel;
    pnlManualBody: TPanel;

    ComPort1: TComPort;
    IdTCPClient1: TIdTCPClient;
    ocvView1: TocvView;
    ocvCameraSource1: TocvCameraSource;
    ocvImageOperation1: TocvImageOperation;
    ocvImageOperation2: TocvImageOperation;
    pcSystemMain: TPageControl;
    tabAutofocusSystem: TTabSheet;
    tabLensSystem: TTabSheet;
    pnlLensPage: TPanel;
    pnlLensLeft: TPanel;
    pnlLensCenter: TPanel;
    scrLensControl: TScrollBox;
    pnlLensConnectionCard: TPanel;
    lblLensConnectionTitle: TLabel;
    lblLensComPort: TLabel;
    cmbLensComPort: TComboBox;
    btnRefreshLensCom: TButton;
    btnConnectLens: TButton;
    shpLensConnectionStatus: TShape;
    lblLensConnectionState: TLabel;
    lblLensBaudRate: TLabel;
    pnlLensControlCard: TPanel;
    lblLensControlTitle: TLabel;
    lblLensSelectTitle: TLabel;
    btnLens4X: TButton;
    btnLens10X: TButton;
    lblActiveLensTitle: TLabel;
    lblActiveLensValue: TLabel;
    lblLensMovementTitle: TLabel;
    lblLensMovementState: TLabel;
    pnlLensSafetyCard: TPanel;
    lblLensSafetyTitle: TLabel;
    btnStopLens: TButton;
    pnlLensResultCard: TPanel;
    lblLensResultTitle: TLabel;
    btnSaveAutoFocusResult: TButton;
    pcLensResult: TPageControl;
    tabLensResult4X: TTabSheet;
    tabLensResult10X: TTabSheet;
    pnlLensResult4XBody: TPanel;
    pcGraphResult4X: TPageControl;
    tabFocusMacro4XResult: TTabSheet;
    chtFocusMacro4XResult: TChart;
    serFocusMacro4XResult: TLineSeries;
    tabOtsuMacro4XResult: TTabSheet;
    chtOtsuMacro4XResult: TChart;
    serOtsuMacro4XResult: TLineSeries;
    tabFocusMicro4XResult: TTabSheet;
    chtFocusMicro4XResult: TChart;
    serFocusMicro4XResult: TLineSeries;
    tabOtsuMicro4XResult: TTabSheet;
    chtOtsuMicro4XResult: TChart;
    serOtsuMicro4XResult: TLineSeries;
    pnlLensResult10XBody: TPanel;
    pcGraphResult10X: TPageControl;
    tabFocusMacro10XResult: TTabSheet;
    chtFocusMacro10XResult: TChart;
    serFocusMacro10XResult: TLineSeries;
    tabOtsuMacro10XResult: TTabSheet;
    chtOtsuMacro10XResult: TChart;
    serOtsuMacro10XResult: TLineSeries;
    tabFocusMicro10XResult: TTabSheet;
    chtFocusMicro10XResult: TChart;
    serFocusMicro10XResult: TLineSeries;
    tabOtsuMicro10XResult: TTabSheet;
    chtOtsuMicro10XResult: TChart;
    serOtsuMicro10XResult: TLineSeries;
    ComPortLens: TComPort;

  protected
    procedure Loaded; override;

  private
    FSerialBuffer: string;

    { Koneksi utama Delphi ke ESP32 A melalui WiFi TCP. }
    FTcpReceiveBuffer: string;
    FTcpReadTimer: TTimer;
    FWiFiConnected: Boolean;

    { Status ESP32 pemilih lensa. }
    FLensSerialBuffer: string;
    FLensInitialPositionConfirmed: Boolean;
    FLensMoving: Boolean;
    FLensStopRequested: Boolean;

    { False = perintah terakhir memakai WiFi TCP ESP32 A.
      True  = perintah terakhir memakai USB Serial ESP32 A. }
    FLensDirectBackupMode: Boolean;

    { 0 = belum diketahui, 1 = Objektif 4×, 2 = Objektif 10×. }
    FLensActive: Integer;

    { State otomatis:
      Mikro 0 -> Makro 0 -> revolver -> sinkronisasi profil Z. }
    FLensChangeState: TLensChangeState;
    FLensTarget: Integer;

    { True bila pengguna menekan No pada konfirmasi awal.
      Posisi fisik diasumsikan 10× dan dipulihkan ke 4×. }
    FRecoverInitialLensFrom10X: Boolean;

    { Status profil objektif yang dilaporkan ESP32 sumbu Z.
      0 = belum diketahui, 1 = 4×, 2 = 10×. }
    FZProfileActive: Integer;
    FZProfileMacroMax: Integer;
    FZProfileReceived: Boolean;
    FZProfileMacroMaxReceived: Boolean;
    FZProfileDoneReceived: Boolean;
    FZProfileSynchronized: Boolean;

    { Verifikasi otomatis bila balasan akhir lensa terlambat/hilang. }
    FLensVerifyTimer: TTimer;
    FLensVerifyRetryCount: Integer;

    { Langkah 73: penanda titik fokus terbaik pada grafik hasil. }
    FBestMacroMarker4X: TPointSeries;
    FBestMicroMarker4X: TPointSeries;
    FBestMacroMarker10X: TPointSeries;
    FBestMicroMarker10X: TPointSeries;

    { Langkah 74: penanda nilai Otsu pada posisi fokus terbaik. }
    FBestMacroOtsuMarker4X: TPointSeries;
    FBestMicroOtsuMarker4X: TPointSeries;
    FBestMacroOtsuMarker10X: TPointSeries;
    FBestMicroOtsuMarker10X: TPointSeries;

    { Ringkasan Autofokus terakhir untuk masing-masing objektif. }
    FResult4XAvailable: Boolean;
    FResult4XBestMacro: Integer;
    FResult4XBestMicro: Integer;
    FResult4XBestMacroFocus: Double;
    FResult4XBestFocus: Double;
    FResult4XBestMacroOtsu: Double;
    FResult4XBestMicroOtsu: Double;

    FResult10XAvailable: Boolean;
    FResult10XBestMacro: Integer;
    FResult10XBestMicro: Integer;
    FResult10XBestMacroFocus: Double;
    FResult10XBestFocus: Double;
    FResult10XBestMacroOtsu: Double;
    FResult10XBestMicroOtsu: Double;

    FPendingMotor: TPendingMotor;
    FMacroPosition: Integer;
    FMicroPosition: Integer;
    FCameraActive: Boolean;

    FLastOtsu: Integer;
    FLastFocus: Double;
    FFrameCounter: Integer;

    FGraphActiveMotor: TPendingMotor;

    FGraphSampleMotor: TPendingMotor;
    FGraphSamplePosition: Integer;
    FGraphSamplePending: Boolean;
    FGraphSampleCount: Integer;
    FGraphSampleTargetCount: Integer;
    FGraphFocusSum: Double;
    FGraphOtsuSum: Double;
    FGraphFocusMin: Double;
    FGraphFocusMax: Double;
    FGraphOtsuMin: Double;
    FGraphOtsuMax: Double;

    FAutoFocusTimer: TTimer;
    FAutoFocusState: TAutoFocusState;
    FAutoFocusPhase: TAutoFocusPhase;
    FAutoFocusMoveMotor: TPendingMotor;
    FAutoFocusRunning: Boolean;
    FAutoFocusStopRequested: Boolean;
    FAutoFocusCurrentTarget: Integer;

    { Batas akhir scan Makrometer yang dikunci ketika Autofokus dimulai. }
    FAutoFocusMacroEnd: Integer;

    FAutoFocusBestMacroPosition: Integer;
    FAutoFocusBestMacroFocus: Double;
    FAutoFocusBestMicroPosition: Integer;
    FAutoFocusBestMicroFocus: Double;

    FAutoFocusBestMicroCoarsePosition: Integer;
    FAutoFocusBestMicroCoarseFocus: Double;
    FAutoFocusMicroFineStart: Integer;
    FAutoFocusMicroFineEnd: Integer;

    FMacroCandidates: TFocusCandidateArray;
    FMacroCandidateCount: Integer;
    FMicroCandidates: TFocusCandidateArray;
    FMicroCandidateCount: Integer;
    FVerifyCandidateIndex: Integer;
    FVerifyBestPosition: Integer;
    FVerifyBestFocus: Double;

    FAutoFocusPointsDone: Integer;
    FAutoFocusTotalPoints: Integer;
    FAutoFocusRunMode: TAutoFocusRunMode;

    { Autofokus otomatis: Makro 4× -> Makro 10× -> pilih pemenang
      -> scan Mikro hanya pada objektif pemenang. }
    FDualAutoFocusActive: Boolean;
    FDualAutoFocusStopRequested: Boolean;
    FDualAutoFocusStage: TDualAutoFocusStage;
    FDualWinnerLens: Integer;

    FDual4XBestMacroPosition: Integer;
    FDual4XBestMacroFocus: Double;
    FDual4XMacroMedian: Double;
    FDual4XMacroQuality: Double;

    FDual10XBestMacroPosition: Integer;
    FDual10XBestMacroFocus: Double;
    FDual10XMacroMedian: Double;
    FDual10XMacroQuality: Double;

    procedure FormDestroy(Sender: TObject);

    { Status jalur komunikasi ESP32 A. }
    function MainConnectionConnected: Boolean;
    function SerialBackupConnected: Boolean;
    function SystemConnectionConnected: Boolean;

    procedure InitializeTcpClient;
    procedure DisconnectTcpClient(
      const AStatusText: string = ''
    );
    procedure TcpReadTimerTick(Sender: TObject);
    procedure ProcessTcpIncomingData(
      const AData: string
    );

    procedure btnRefreshComClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);

    { Koneksi USB Serial cadangan menuju ESP32 A. }
    procedure btnRefreshLensComClick(Sender: TObject);
    procedure btnConnectLensClick(Sender: TObject);
    procedure btnLens4XClick(Sender: TObject);
    procedure btnLens10XClick(Sender: TObject);
    procedure btnStopLensClick(Sender: TObject);

    procedure InitializeLensConnectionControls;
    procedure LoadLensComList;
    procedure SetLensConnectionState(AConnected: Boolean);
    procedure UpdateLensControlState;
    procedure ConfirmInitialLens4X;
    procedure RequestLensChange(
      ATargetLens: Integer;
      AInternalDualAutoFocus: Boolean = False
    );

    procedure StartLensSafetySequence;
    procedure ContinueLensSafetyAfterMotorDone(
      AMotor: TPendingMotor
    );
    procedure StartLensObjectiveMove;
    procedure AbortLensChange(
      const AReason: string;
      AShowMessage: Boolean = False
    );

    function ExpectedMacroMaxForLens(
      ALens: Integer
    ): Integer;

    function ActiveMacroMaximum: Integer;
    procedure ApplyActiveMacroRange;

    procedure StartZProfileSync;
    procedure EvaluateZProfileStatus;
    procedure CompleteZProfileSync;
    procedure FailZProfileSync(
      const AReason: string;
      AShowMessage: Boolean = True
    );

    function SendLensCommand(
      const ACommand: string
    ): Boolean;

    function LensCommandChannelAvailable: Boolean;
    function LensCommandUsesPrimary: Boolean;

    procedure ComPortLensRxChar(
      Sender: TObject;
      Count: Integer
    );

    procedure ProcessLensSerialLine(
      const ALine: string
    );

    procedure LensVerifyTimerTick(Sender: TObject);
    procedure StartLensVerificationTimer;
    procedure StopLensVerificationTimer;
    procedure CompleteLensMovement(
      AConfirmedLens: Integer
    );

    procedure btnMoveMacroClick(Sender: TObject);
    procedure btnMoveMicroClick(Sender: TObject);

    procedure btnStartCameraClick(Sender: TObject);
    procedure btnStopCameraClick(Sender: TObject);
    procedure btnCameraSettingsClick(Sender: TObject);

    procedure btnStartAutoFocusClick(Sender: TObject);
    procedure btnStartDualAutoFocusClick(Sender: TObject);
    procedure btnStopAutoFocusClick(Sender: TObject);
    procedure AutoFocusTimerTick(Sender: TObject);

    procedure ProcessingModeClick(Sender: TObject);
    procedure tbThresholdChange(Sender: TObject);
    procedure chkInvertThresholdClick(Sender: TObject);

    procedure edtMacroTargetKeyPress(
      Sender: TObject;
      var Key: Char
    );

    procedure edtMicroTargetKeyPress(
      Sender: TObject;
      var Key: Char
    );

    procedure ComPort1RxChar(
      Sender: TObject;
      Count: Integer
    );

    procedure ocvView1BeforePaint(
      Sender: TObject;
      var IplImage: IocvImage
    );

    procedure InitializeInterface;
    procedure InitializeConnectionControls;
    procedure InitializeCameraControls;
    procedure InitializeProcessingControls;
    procedure InitializeMotorControls;
    procedure InitializeAutoFocusControls;
    procedure InitializeCharts;
    procedure ClearAllGraphSeries;

    { Langkah 72: menyimpan grafik Autofokus terakhir per objektif. }
    procedure InitializeLensResultCharts;

    procedure ConfigureLensResultChart(
      AChart: TChart;
      ASeries: TLineSeries;
      const ATitle: string;
      const AXTitle: string;
      const AYTitle: string;
      AXMinimum: Double;
      AXMaximum: Double;
      AXIncrement: Double
    );

    procedure CopyLineSeriesData(
      ASource: TLineSeries;
      ADestination: TLineSeries
    );

    procedure ConfigureBestPointMarker(
      AChart: TChart;
      var AMarker: TPointSeries
    );

    procedure SetBestPointMarker(
      AMarker: TPointSeries;
      AXValue: Double;
      AYValue: Double
    );

    function TryGetSeriesYAtX(
      ASeries: TLineSeries;
      AXValue: Double;
      out AYValue: Double
    ): Boolean;

    procedure SetResultChartTitle(
      AChart: TChart;
      const ABaseTitle: string;
      const ASummary: string
    );

    procedure UpdateLensResultSummary(
      ALens: Integer
    );

    procedure SaveCompletedAutoFocusResult;

    { Langkah 75B: ekspor manual melalui tombol dari Form Designer. }
    procedure UpdateSaveResultButtonState;
    procedure pcLensResultChange(Sender: TObject);
    procedure btnSaveAutoFocusResultClick(Sender: TObject);

    function SelectedLensResult: Integer;
    function CsvNumber(AValue: Double): string;

    procedure SaveSummaryCsv(
      ALens: Integer;
      const AFileName: string
    );

    procedure SaveGraphDataCsv(
      AFocusSeries: TLineSeries;
      AOtsuSeries: TLineSeries;
      const AFileName: string
    );

    procedure SaveChartAsPng(
      AChart: TChart;
      const AFileName: string
    );

    procedure ExportLensResult(
      ALens: Integer;
      const AFolder: string
    );

    procedure LoadComList;
    procedure SetConnectionState(AConnected: Boolean);
    procedure UpdateMotorControlState;
    procedure ProcessSerialLine(const ALine: string);

    function SendCommand(const ACommand: string): Boolean;
    function SendMacroTarget(ATarget: Integer): Boolean;
    function SendMicroTarget(ATarget: Integer): Boolean;

    procedure SetSelectedCamera;
    procedure ConfigureGrayOperation;
    procedure ConfigureThresholdOperation;
    procedure UpdateThresholdManualOperation;
    procedure UpdateThresholdOtsuOperation;
    procedure SetupCamera;
    procedure StartCamera;
    procedure StopCamera;
    procedure ApplyCameraMode;
    procedure ShowCameraNormal;
    procedure ShowCameraGrayScale;
    procedure ShowCameraThresholdManual;
    procedure ShowCameraThresholdOtsu;
    procedure SetCameraState(AActive: Boolean);
    procedure UpdateCameraControlState;

    function AmbilGray(
      const Img: IocvImage;
      X, Y: Integer
    ): Byte;

    function HitungOtsuDariImage(
      const Img: IocvImage
    ): Integer;

    function HitungFocusScoreDariImage(
      const Img: IocvImage;
      AOtsuThreshold: Integer
    ): Double;

    procedure UpdateNilaiOtsuDanFocus(
      const PaintImage: IocvImage
    );

    procedure ResetGraphSampling;
    procedure StartGraphSampling(
      AMotor: TPendingMotor;
      APosition: Integer;
      ASampleCount: Integer = 0
    );

    procedure AddGraphPoint(
      AMotor: TPendingMotor;
      APosition: Integer;
      AFocus: Double;
      AOtsu: Double
    );

    procedure StartFullAutoFocus;
    procedure StartMacroOnlyAutoFocus;
    procedure StartMicroOnlyAutoFocus(
      ABestMacroPosition: Integer;
      ABestMacroFocus: Double
    );

    procedure StartDualAutoFocus;
    procedure ContinueDualAutoFocusAfterLensReady;
    procedure ContinueDualAutoFocusAfterMacroScan;
    procedure SelectDualAutoFocusWinner;
    procedure FinishDualAutoFocus;
    procedure CancelDualAutoFocus(
      const AReason: string;
      AShowMessage: Boolean = False
    );

    function CalculateSeriesMedian(
      ASeries: TLineSeries
    ): Double;

    function CalculateMacroRelativeQuality(
      ASeries: TLineSeries;
      APeakFocus: Double;
      out AMedianFocus: Double
    ): Double;

    { Menghitung rata-rata Focus Score di sekitar posisi puncak.
      Digunakan sebagai pemeriksaan kestabilan puncak agar keputusan
      tidak hanya bergantung pada satu titik yang mungkin berupa noise. }
    function CalculatePeakNeighborhoodAverage(
      ASeries: TLineSeries;
      APeakPosition: Integer;
      ARadius: Integer
    ): Double;

    procedure SaveCompletedMacroOnlyResult(
      ALens: Integer
    );

    procedure StartMacroScan;
    procedure StartMacroVerification;
    procedure StartMicroCoarseScan;
    procedure StartMicroFineScan;
    procedure StartMicroVerification;

    procedure ResetCandidateList(
      var AList: TFocusCandidateArray;
      var ACount: Integer
    );

    procedure AddFocusCandidate(
      var AList: TFocusCandidateArray;
      var ACount: Integer;
      APosition: Integer;
      AScore: Double
    );

    procedure BeginSettledSampling(
      AMotor: TPendingMotor
    );

    procedure QueueAutoFocusMove(
      AMotor: TPendingMotor;
      ATarget: Integer;
      AReturning: Boolean
    );

    procedure QueueReturnMacroBest;
    procedure QueueReturnMicroBest;

    procedure HandleAutoFocusMotorDone(
      AMotor: TPendingMotor
    );

    procedure HandleAutoFocusSample(
      AMotor: TPendingMotor;
      APosition: Integer;
      AFocus: Double;
      AOtsu: Double
    );

    procedure CompleteMacroOnlyAutoFocus;
    procedure CompleteFullAutoFocus;

    procedure CancelAutoFocus(
      const AReason: string
    );

    procedure AbortAutoFocus(
      const AReason: string
    );

    procedure UpdateAutoFocusProgress;
    procedure UpdateAllControlStates;

    procedure SetStatus(const AText: string);

  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

const
  MACRO_MIN_POS = 0;

  MACRO_MAX_4X = 3800;
  MACRO_MAX_10X = 3200;

  { Batas keras tertinggi seluruh sistem. }
  MACRO_MAX_POS = MACRO_MAX_4X;

  MICRO_MIN_POS = -1600;
  MICRO_MAX_POS = 1600;

  AUTOFOCUS_MACRO_START = 0;
  AUTOFOCUS_MACRO_STEP = 50;

  AUTOFOCUS_MICRO_START = -1600;
  AUTOFOCUS_MICRO_END = 1600;

  AUTOFOCUS_MICRO_COARSE_STEP = 100;
  AUTOFOCUS_MICRO_FINE_STEP = 10;
  AUTOFOCUS_MICRO_FINE_HALF_RANGE = 100;
  AUTOFOCUS_MICRO_BACKLASH_STEPS = 10;

  AUTOFOCUS_SAMPLE_COUNT = 9;
  AUTOFOCUS_VERIFY_SAMPLE_COUNT = 15;
  AUTOFOCUS_CANDIDATE_COUNT = 3;

  AUTOFOCUS_SETTLE_DELAY_MS = 500;
  AUTOFOCUS_VERIFY_SETTLE_DELAY_MS = 800;
  AUTOFOCUS_COMMAND_DELAY_MS = 300;

  { Motor lensa membutuhkan sekitar 3,2 detik untuk 3200 pulsa.
    Sesudah 4,5 detik Delphi meminta ulang status objektif. }
  LENS_VERIFY_FIRST_DELAY_MS = 4500;
  LENS_VERIFY_RETRY_DELAY_MS = 1200;
  LENS_VERIFY_MAX_RETRY = 3;

  { Konfigurasi WiFi ESP32 A sebagai Access Point + TCP Server. }
  WIFI_AP_SSID = 'MIKROSKOP_ESP32';
  WIFI_TCP_HOST = '192.168.4.1';
  WIFI_TCP_PORT = 5000;
  WIFI_CONNECT_TIMEOUT_MS = 3000;
  WIFI_READ_TIMEOUT_MS = 3000;
  WIFI_POLL_INTERVAL_MS = 25;

{ ============================================================================
  INISIALISASI FORM
  ============================================================================ }

procedure TfrmMain.Loaded;
begin
  inherited;

  if csDesigning in ComponentState then
    Exit;

  OnDestroy := FormDestroy;

  { Bila komponen IdTCPClient1 belum tersimpan pada DFM, buat secara
    runtime agar kode tetap dapat digunakan. Bila sudah ada pada Form
    Designer, blok ini tidak membuat komponen kedua. }
  if not Assigned(IdTCPClient1) then
    IdTCPClient1 := TIdTCPClient.Create(Self);

  FTcpReadTimer := TTimer.Create(Self);
  FTcpReadTimer.Enabled := False;
  FTcpReadTimer.Interval := WIFI_POLL_INTERVAL_MS;
  FTcpReadTimer.OnTimer := TcpReadTimerTick;

  btnRefreshCom.OnClick := btnRefreshComClick;
  btnConnect.OnClick := btnConnectClick;

  { Tombol koneksi serial cadangan ESP32 A dan kontrol objektif. }
  btnRefreshLensCom.OnClick := btnRefreshLensComClick;
  btnConnectLens.OnClick := btnConnectLensClick;
  btnLens4X.OnClick := btnLens4XClick;
  btnLens10X.OnClick := btnLens10XClick;
  btnStopLens.OnClick := btnStopLensClick;

  { Tombol Simpan Hasil dibuat manual di Form Designer. }
  btnSaveAutoFocusResult.OnClick :=
    btnSaveAutoFocusResultClick;

  pcLensResult.OnChange :=
    pcLensResultChange;

  btnMoveMacro.OnClick := btnMoveMacroClick;
  btnMoveMicro.OnClick := btnMoveMicroClick;

  btnStartCamera.OnClick := btnStartCameraClick;
  btnStopCamera.OnClick := btnStopCameraClick;
  btnCameraSettings.OnClick := btnCameraSettingsClick;

  btnStartAutoFocus.OnClick := btnStartAutoFocusClick;
  btnStartDualAutoFocus.OnClick := btnStartDualAutoFocusClick;
  btnStopAutoFocus.OnClick := btnStopAutoFocusClick;

  FAutoFocusTimer := TTimer.Create(Self);
  FAutoFocusTimer.Enabled := False;
  FAutoFocusTimer.Interval := AUTOFOCUS_COMMAND_DELAY_MS;
  FAutoFocusTimer.OnTimer := AutoFocusTimerTick;

  FLensVerifyTimer := TTimer.Create(Self);
  FLensVerifyTimer.Enabled := False;
  FLensVerifyTimer.Interval := LENS_VERIFY_FIRST_DELAY_MS;
  FLensVerifyTimer.OnTimer := LensVerifyTimerTick;
  FLensVerifyRetryCount := 0;

  rbNormal.OnClick := ProcessingModeClick;
  rbGrayscale.OnClick := ProcessingModeClick;
  rbThresholdManual.OnClick := ProcessingModeClick;
  rbThresholdOtsu.OnClick := ProcessingModeClick;

  tbThreshold.OnChange := tbThresholdChange;
  chkInvertThreshold.OnClick := chkInvertThresholdClick;

  edtMacroTarget.OnKeyPress := edtMacroTargetKeyPress;
  edtMicroTarget.OnKeyPress := edtMicroTargetKeyPress;

  { ComPort1 tetap berada pada Form sebagai jalur servis lama,
    tetapi koneksi utama sekarang memakai IdTCPClient1. }
  ComPort1.OnRxChar := nil;
  ComPortLens.OnRxChar := ComPortLensRxChar;

  ocvView1.OnBeforePaint := ocvView1BeforePaint;

  InitializeInterface;
end;

procedure TfrmMain.InitializeInterface;
begin
  Caption := 'Sistem Autofokus Mikroskop Digital';

  stbMain.SimplePanel := True;

  pcMainView.ActivePage := tabMonitor;
  pcRightControl.ActivePage := tabManualControl;
  pcGraphView.ActivePage := tabFocusGraph;

  InitializeCameraControls;
  InitializeProcessingControls;
  InitializeMotorControls;
  InitializeAutoFocusControls;
  InitializeCharts;
  InitializeConnectionControls;
  InitializeLensConnectionControls;
  UpdateSaveResultButtonState;

  SetStatus(
    'Hubungkan laptop ke WiFi ' + WIFI_AP_SSID +
    ', lalu tekan Hubungkan'
  );
end;

{ ============================================================================
  INISIALISASI KONEKSI
  ============================================================================ }

function TfrmMain.MainConnectionConnected: Boolean;
begin
  Result :=
    FWiFiConnected and
    Assigned(IdTCPClient1) and
    IdTCPClient1.Connected;
end;

function TfrmMain.SerialBackupConnected: Boolean;
begin
  Result :=
    Assigned(ComPortLens) and
    ComPortLens.Connected;
end;

function TfrmMain.SystemConnectionConnected: Boolean;
begin
  Result :=
    MainConnectionConnected or
    SerialBackupConnected;
end;

procedure TfrmMain.InitializeTcpClient;
begin
  if not Assigned(IdTCPClient1) then
    Exit;

  IdTCPClient1.Host := WIFI_TCP_HOST;
  IdTCPClient1.Port := WIFI_TCP_PORT;
  IdTCPClient1.ConnectTimeout := WIFI_CONNECT_TIMEOUT_MS;
  IdTCPClient1.ReadTimeout := WIFI_READ_TIMEOUT_MS;

  FTcpReceiveBuffer := '';
  FWiFiConnected := False;
end;

procedure TfrmMain.DisconnectTcpClient(
  const AStatusText: string
);
begin
  if Assigned(FTcpReadTimer) then
    FTcpReadTimer.Enabled := False;

  try
    if Assigned(IdTCPClient1) and
       IdTCPClient1.Connected then
    begin
      IdTCPClient1.Disconnect;
    end;
  except
    { Proses penutupan koneksi tidak boleh menghambat penutupan aplikasi. }
  end;

  FWiFiConnected := False;
  FTcpReceiveBuffer := '';

  if AStatusText <> '' then
    SetStatus(AStatusText);
end;

procedure TfrmMain.ProcessTcpIncomingData(
  const AData: string
);
var
  Baris: string;
  PosNewLine: Integer;
begin
  if AData = '' then
    Exit;

  FTcpReceiveBuffer := FTcpReceiveBuffer + AData;
  PosNewLine := Pos(#10, FTcpReceiveBuffer);

  while PosNewLine > 0 do
  begin
    Baris := Copy(
      FTcpReceiveBuffer,
      1,
      PosNewLine - 1
    );

    Delete(
      FTcpReceiveBuffer,
      1,
      PosNewLine
    );

    Baris := StringReplace(
      Baris,
      #13,
      '',
      [rfReplaceAll]
    );

    Baris := Trim(Baris);

    if Baris <> '' then
      ProcessSerialLine(Baris);

    PosNewLine := Pos(#10, FTcpReceiveBuffer);
  end;

  { Lindungi aplikasi apabila perangkat mengirim data tanpa karakter akhir. }
  if Length(FTcpReceiveBuffer) > 4096 then
  begin
    FTcpReceiveBuffer := '';
    SetStatus('Buffer TCP dikosongkan karena data terlalu panjang');
  end;
end;

procedure TfrmMain.TcpReadTimerTick(
  Sender: TObject
);
var
  DataMasuk: string;
begin
  if not MainConnectionConnected then
    Exit;

  try
    { Polling tanpa blocking. Data yang tersedia dipindahkan dari socket
      ke InputBuffer Indy, kemudian dibaca sekaligus dan dipisah per baris. }
    IdTCPClient1.IOHandler.CheckForDataOnSource(0);

    if IdTCPClient1.IOHandler.InputBufferIsEmpty then
      Exit;

    DataMasuk :=
      IdTCPClient1.IOHandler.InputBufferAsString;

    ProcessTcpIncomingData(DataMasuk);
  except
    on E: Exception do
    begin
      DisconnectTcpClient('Koneksi WiFi TCP terputus');
      SetConnectionState(False);

      SetStatus(
        'Koneksi WiFi TCP terputus: ' + E.Message
      );
    end;
  end;
end;

procedure TfrmMain.InitializeConnectionControls;
begin
  FSerialBuffer := '';
  FTcpReceiveBuffer := '';
  FWiFiConnected := False;

  FPendingMotor := pmNone;
  FMacroPosition := 0;
  FMicroPosition := 0;

  InitializeTcpClient;

  btnConnect.Caption := 'Hubungkan';

  lblConnectionState.Caption := 'Belum terhubung';
  lblComPort.Caption := 'WiFi ESP32 A';
  lblBaudRate.Caption :=
    WIFI_TCP_HOST + ':' + IntToStr(WIFI_TCP_PORT);

  shpConnectionStatus.Brush.Color := clSilver;

  LoadComList;
  SetConnectionState(False);
end;

procedure TfrmMain.InitializeLensConnectionControls;
begin
  FLensSerialBuffer := '';
  FLensInitialPositionConfirmed := False;
  FLensMoving := False;
  FLensStopRequested := False;
  FLensDirectBackupMode := False;
  FLensActive := 0;
  FLensChangeState := lcsIdle;
  FLensTarget := 0;
  FRecoverInitialLensFrom10X := False;

  FLensVerifyRetryCount := 0;
  StopLensVerificationTimer;

  FZProfileActive := 0;
  FZProfileMacroMax := 0;
  FZProfileReceived := False;
  FZProfileMacroMaxReceived := False;
  FZProfileDoneReceived := False;
  FZProfileSynchronized := False;

  ComPortLens.BaudRate := br115200;

  LoadLensComList;
  SetLensConnectionState(False);
end;

procedure TfrmMain.SetLensConnectionState(
  AConnected: Boolean
);
begin
  if AConnected then
  begin
    btnConnectLens.Caption := 'Putuskan';
    cmbLensComPort.Enabled := False;
    btnRefreshLensCom.Enabled := False;
    lblLensConnectionState.Caption := 'Terhubung (cadangan)';
    lblLensBaudRate.Caption := '115200 bps';
    shpLensConnectionStatus.Brush.Color := clLime;
  end
  else
  begin
    btnConnectLens.Caption := 'Hubungkan';
    cmbLensComPort.Enabled := True;
    btnRefreshLensCom.Enabled := True;
    lblLensConnectionState.Caption := 'Belum terhubung';
    lblLensBaudRate.Caption := '115200 bps';
    shpLensConnectionStatus.Brush.Color := clSilver;

    FLensSerialBuffer := '';

    { Memutus COM cadangan tidak boleh menghapus status sistem
      apabila koneksi WiFi ESP32 A masih terhubung. }
    if not SystemConnectionConnected then
    begin
      FLensInitialPositionConfirmed := False;
      FLensMoving := False;
      FLensStopRequested := False;
      FLensDirectBackupMode := False;
      FLensActive := 0;
      FLensChangeState := lcsIdle;
      FLensTarget := 0;
      FRecoverInitialLensFrom10X := False;
      FZProfileSynchronized := False;

      lblActiveLensValue.Caption := '-';
      lblLensMovementState.Caption := 'Menunggu koneksi';
    end;
  end;

  UpdateLensControlState;
  UpdateMotorControlState;
end;

procedure TfrmMain.UpdateLensControlState;
var
  Connected: Boolean;
  LensReady: Boolean;
  LensSequenceIdle: Boolean;
  ProfileReady: Boolean;
begin
  Connected := LensCommandChannelAvailable;
  LensSequenceIdle := FLensChangeState = lcsIdle;

  { WiFi dan COM cadangan sama-sama menuju ESP32 A.
    Karena itu profil Z wajib sinkron pada kedua jalur. }
  ProfileReady :=
    SystemConnectionConnected and
    FZProfileSynchronized;

  LensReady :=
    Connected and
    FLensInitialPositionConfirmed and
    ProfileReady and
    LensSequenceIdle and
    (not FLensMoving) and
    (not FDualAutoFocusActive);

  btnLens4X.Enabled := LensReady and (FLensActive <> 1);
  btnLens10X.Enabled := LensReady and (FLensActive <> 2);

  btnStopLens.Enabled :=
    Connected and
    FLensMoving and
    (FLensChangeState = lcsMoveObjective) and
    (not FLensStopRequested);

  { Tombol ini mengatur USB Serial cadangan menuju ESP32 A. }
  btnConnectLens.Enabled :=
    LensSequenceIdle and
    (not FLensMoving) and
    (not FDualAutoFocusActive);
end;

procedure TfrmMain.SetConnectionState(AConnected: Boolean);
begin
  if AConnected then
  begin
    btnConnect.Caption := 'Putuskan';

    cmbComPort.Enabled := False;
    btnRefreshCom.Enabled := False;

    lblConnectionState.Caption := 'Terhubung via WiFi';
    lblBaudRate.Caption :=
      WIFI_TCP_HOST + ':' + IntToStr(WIFI_TCP_PORT);

    shpConnectionStatus.Brush.Color := clLime;
  end
  else
  begin
    btnConnect.Caption := 'Hubungkan';

    { SSID dan alamat TCP bersifat tetap, sehingga ComboBox hanya
      berfungsi sebagai informasi tanpa mengubah susunan tampilan. }
    cmbComPort.Enabled := False;
    btnRefreshCom.Enabled := True;

    lblConnectionState.Caption := 'Belum terhubung';
    lblBaudRate.Caption :=
      WIFI_TCP_HOST + ':' + IntToStr(WIFI_TCP_PORT);

    shpConnectionStatus.Brush.Color := clSilver;

    { Bila COM cadangan ESP32 A masih aktif, status posisi dan profil
      tidak boleh dihapus hanya karena WiFi diputuskan. }
    if not SerialBackupConnected then
    begin
      FPendingMotor := pmNone;
      FZProfileActive := 0;
      FZProfileMacroMax := 0;
      FZProfileReceived := False;
      FZProfileMacroMaxReceived := False;
      FZProfileDoneReceived := False;
      FZProfileSynchronized := False;
    end;
  end;

  UpdateLensControlState;
  UpdateMotorControlState;
end;

{ ============================================================================
  KONDISI KONTROL MOTOR
  ============================================================================ }

procedure TfrmMain.UpdateMotorControlState;
var
  Connected: Boolean;
  MotorIdle: Boolean;
  ProfileSafe: Boolean;
begin
  Connected := SystemConnectionConnected;

  ProfileSafe :=
    (not FLensInitialPositionConfirmed) or
    FZProfileSynchronized;

  MotorIdle :=
    (FPendingMotor = pmNone) and
    (not FGraphSamplePending) and
    (not FAutoFocusRunning) and
    (not FDualAutoFocusActive) and
    (FLensChangeState = lcsIdle) and
    (not FLensMoving) and
    ProfileSafe;

  edtMacroTarget.Enabled := Connected and MotorIdle;
  edtMicroTarget.Enabled := Connected and MotorIdle;
  btnMoveMacro.Enabled := Connected and MotorIdle;
  btnMoveMicro.Enabled := Connected and MotorIdle;

  btnStartAutoFocus.Enabled :=
    Connected and
    FCameraActive and
    MotorIdle;

  btnStartDualAutoFocus.Enabled :=
    Connected and
    FCameraActive and
    MotorIdle and
    LensCommandChannelAvailable and
    FLensInitialPositionConfirmed and
    FZProfileSynchronized and
    (FLensActive in [1, 2]);

  btnStopAutoFocus.Enabled :=
    (FAutoFocusRunning or FDualAutoFocusActive) and
    (not FAutoFocusStopRequested) and
    (not FDualAutoFocusStopRequested);

  btnConnect.Enabled :=
    (not FAutoFocusRunning) and
    (not FDualAutoFocusActive) and
    (FLensChangeState = lcsIdle) and
    (not FLensMoving);

  if FAutoFocusRunning or
     FDualAutoFocusActive or
     (FLensChangeState <> lcsIdle) or
     FLensMoving then
    btnRefreshCom.Enabled := False
  else
    { Tombol refresh ini khusus panel WiFi, sehingga tetap tersedia
      ketika hanya COM cadangan yang sedang aktif. }
    btnRefreshCom.Enabled := not MainConnectionConnected;
end;

{ ============================================================================
  DETEKSI COM PORT
  ============================================================================ }

function TfrmMain.SelectedLensResult: Integer;
begin
  if pcLensResult.ActivePage =
     tabLensResult10X then
  begin
    Result := 2;
  end
  else
  begin
    Result := 1;
  end;
end;

procedure TfrmMain.UpdateSaveResultButtonState;
var
  Lens: Integer;
begin
  if not Assigned(btnSaveAutoFocusResult) then
    Exit;

  Lens := SelectedLensResult;

  case Lens of
    1:
      begin
        btnSaveAutoFocusResult.Caption :=
          'Simpan Hasil Objektif 4×';

        btnSaveAutoFocusResult.Enabled :=
          FResult4XAvailable;
      end;

    2:
      begin
        btnSaveAutoFocusResult.Caption :=
          'Simpan Hasil Objektif 10×';

        btnSaveAutoFocusResult.Enabled :=
          FResult10XAvailable;
      end;
  else
    begin
      btnSaveAutoFocusResult.Caption :=
        'Simpan Hasil';

      btnSaveAutoFocusResult.Enabled :=
        False;
    end;
  end;
end;

procedure TfrmMain.pcLensResultChange(
  Sender: TObject
);
begin
  UpdateSaveResultButtonState;
end;

function TfrmMain.CsvNumber(
  AValue: Double
): string;
var
  CsvFormat: TFormatSettings;
begin
  CsvFormat := TFormatSettings.Create;
  CsvFormat.DecimalSeparator := ',';
  CsvFormat.ThousandSeparator := '.';

  Result :=
    FormatFloat(
      '0.000',
      AValue,
      CsvFormat
    );
end;

procedure TfrmMain.SaveSummaryCsv(
  ALens: Integer;
  const AFileName: string
);
var
  Lines: TStringList;
  LensText: string;
  BestMacro: Integer;
  BestMicro: Integer;
  BestMacroFocus: Double;
  BestFocus: Double;
  BestMacroOtsu: Double;
  BestMicroOtsu: Double;
begin
  case ALens of
    1:
      begin
        LensText := '4X';
        BestMacro := FResult4XBestMacro;
        BestMicro := FResult4XBestMicro;
        BestMacroFocus := FResult4XBestMacroFocus;
        BestFocus := FResult4XBestFocus;
        BestMacroOtsu := FResult4XBestMacroOtsu;
        BestMicroOtsu := FResult4XBestMicroOtsu;
      end;

    2:
      begin
        LensText := '10X';
        BestMacro := FResult10XBestMacro;
        BestMicro := FResult10XBestMicro;
        BestMacroFocus := FResult10XBestMacroFocus;
        BestFocus := FResult10XBestFocus;
        BestMacroOtsu := FResult10XBestMacroOtsu;
        BestMicroOtsu := FResult10XBestMicroOtsu;
      end;
  else
    Exit;
  end;

  Lines := TStringList.Create;
  try
    Lines.Add('Parameter;Nilai');

    Lines.Add(
      'Tanggal dan waktu;' +
      FormatDateTime(
        'dd/mm/yyyy hh:nn:ss',
        Now
      )
    );

    Lines.Add(
      'Objektif;' +
      LensText
    );

    Lines.Add(
      'Makro terbaik;' +
      IntToStr(BestMacro)
    );

    Lines.Add(
      'Mikro terbaik;' +
      IntToStr(BestMicro)
    );

    Lines.Add(
      'Focus Makro terbaik;' +
      CsvNumber(BestMacroFocus)
    );

    Lines.Add(
      'Focus akhir;' +
      CsvNumber(BestFocus)
    );

    Lines.Add(
      'Otsu pada Makro terbaik;' +
      CsvNumber(BestMacroOtsu)
    );

    Lines.Add(
      'Otsu pada Mikro terbaik;' +
      CsvNumber(BestMicroOtsu)
    );

    Lines.Add(
      'Interval scan Makro;' +
      IntToStr(AUTOFOCUS_MACRO_STEP)
    );

    Lines.Add(
      'Rentang scan Mikro;' +
      IntToStr(AUTOFOCUS_MICRO_START) +
      ' sampai ' +
      IntToStr(AUTOFOCUS_MICRO_END)
    );

    Lines.SaveToFile(
      AFileName,
      TEncoding.UTF8
    );
  finally
    Lines.Free;
  end;
end;

procedure TfrmMain.SaveGraphDataCsv(
  AFocusSeries: TLineSeries;
  AOtsuSeries: TLineSeries;
  const AFileName: string
);
var
  Lines: TStringList;
  I: Integer;
  OtsuValue: Double;
  OtsuText: string;
begin
  if (AFocusSeries = nil) or
     (AFocusSeries.Count = 0) then
  begin
    raise Exception.Create(
      'Data grafik Focus belum tersedia.'
    );
  end;

  Lines := TStringList.Create;
  try
    Lines.Add(
      'Posisi;Focus Score;Nilai Otsu'
    );

    for I := 0 to AFocusSeries.Count - 1 do
    begin
      if TryGetSeriesYAtX(
        AOtsuSeries,
        AFocusSeries.XValue[I],
        OtsuValue
      ) then
      begin
        OtsuText := CsvNumber(OtsuValue);
      end
      else
      begin
        OtsuText := '';
      end;

      Lines.Add(
        CsvNumber(
          AFocusSeries.XValue[I]
        ) +
        ';' +
        CsvNumber(
          AFocusSeries.YValue[I]
        ) +
        ';' +
        OtsuText
      );
    end;

    Lines.SaveToFile(
      AFileName,
      TEncoding.UTF8
    );
  finally
    Lines.Free;
  end;
end;

procedure TfrmMain.SaveChartAsPng(
  AChart: TChart;
  const AFileName: string
);
var
  TemporaryBitmapFile: string;
  Bitmap: TBitmap;
  PngImage: TPngImage;
begin
  if AChart = nil then
  begin
    raise Exception.Create(
      'Komponen grafik tidak tersedia.'
    );
  end;

  TemporaryBitmapFile :=
    ChangeFileExt(
      AFileName,
      '.temporary.bmp'
    );

  Bitmap := TBitmap.Create;
  PngImage := TPngImage.Create;
  try
    AChart.SaveToBitmapFile(
      TemporaryBitmapFile
    );

    Bitmap.LoadFromFile(
      TemporaryBitmapFile
    );

    PngImage.Assign(Bitmap);

    PngImage.SaveToFile(
      AFileName
    );
  finally
    PngImage.Free;
    Bitmap.Free;

    if FileExists(TemporaryBitmapFile) then
      DeleteFile(TemporaryBitmapFile);
  end;
end;

procedure TfrmMain.ExportLensResult(
  ALens: Integer;
  const AFolder: string
);
begin
  if not ForceDirectories(AFolder) then
  begin
    raise Exception.Create(
      'Folder hasil tidak dapat dibuat.'
    );
  end;

  case ALens of
    1:
      begin
        SaveSummaryCsv(
          1,
          IncludeTrailingPathDelimiter(AFolder) +
          'Ringkasan.csv'
        );

        SaveGraphDataCsv(
          serFocusMacro4XResult,
          serOtsuMacro4XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Data_Makro.csv'
        );

        SaveGraphDataCsv(
          serFocusMicro4XResult,
          serOtsuMicro4XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Data_Mikro.csv'
        );

        SaveChartAsPng(
          chtFocusMacro4XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Focus_Makro_4X.png'
        );

        SaveChartAsPng(
          chtOtsuMacro4XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Otsu_Makro_4X.png'
        );

        SaveChartAsPng(
          chtFocusMicro4XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Focus_Mikro_4X.png'
        );

        SaveChartAsPng(
          chtOtsuMicro4XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Otsu_Mikro_4X.png'
        );
      end;

    2:
      begin
        SaveSummaryCsv(
          2,
          IncludeTrailingPathDelimiter(AFolder) +
          'Ringkasan.csv'
        );

        SaveGraphDataCsv(
          serFocusMacro10XResult,
          serOtsuMacro10XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Data_Makro.csv'
        );

        SaveGraphDataCsv(
          serFocusMicro10XResult,
          serOtsuMicro10XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Data_Mikro.csv'
        );

        SaveChartAsPng(
          chtFocusMacro10XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Focus_Makro_10X.png'
        );

        SaveChartAsPng(
          chtOtsuMacro10XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Otsu_Makro_10X.png'
        );

        SaveChartAsPng(
          chtFocusMicro10XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Focus_Mikro_10X.png'
        );

        SaveChartAsPng(
          chtOtsuMicro10XResult,
          IncludeTrailingPathDelimiter(AFolder) +
          'Otsu_Mikro_10X.png'
        );
      end;
  else
    raise Exception.Create(
      'Objektif hasil tidak valid.'
    );
  end;
end;

procedure TfrmMain.btnSaveAutoFocusResultClick(
  Sender: TObject
);
var
  Lens: Integer;
  BaseFolder: string;
  ResultFolder: string;
  LensFolderText: string;
begin
  Lens := SelectedLensResult;

  if ((Lens = 1) and
      (not FResult4XAvailable)) or
     ((Lens = 2) and
      (not FResult10XAvailable)) then
  begin
    ShowMessage(
      'Belum ada hasil Autofokus yang dapat disimpan ' +
      'untuk objektif ini.'
    );

    Exit;
  end;

  BaseFolder := '';

  if not SelectDirectory(
    'Pilih folder penyimpanan hasil Autofokus',
    '',
    BaseFolder
  ) then
  begin
    Exit;
  end;

  case Lens of
    1:
      LensFolderText := 'Objektif_4X';

    2:
      LensFolderText := 'Objektif_10X';
  else
    Exit;
  end;

  ResultFolder :=
    IncludeTrailingPathDelimiter(BaseFolder) +
    FormatDateTime(
      'yyyy-mm-dd_hh-nn-ss',
      Now
    ) +
    '_' +
    LensFolderText;

  try
    ExportLensResult(
      Lens,
      ResultFolder
    );

    SetStatus(
      'Hasil Autofokus berhasil disimpan ke: ' +
      ResultFolder
    );

    ShowMessage(
      'Hasil Autofokus berhasil disimpan.' +
      sLineBreak +
      sLineBreak +
      ResultFolder
    );
  except
    on E: Exception do
    begin
      SetStatus(
        'Gagal menyimpan hasil Autofokus: ' +
        E.Message
      );

      ShowMessage(
        'Gagal menyimpan hasil Autofokus.' +
        sLineBreak +
        sLineBreak +
        E.Message
      );
    end;
  end;
end;

procedure TfrmMain.LoadComList;
begin
  cmbComPort.Items.BeginUpdate;
  try
    cmbComPort.Clear;
    cmbComPort.Items.Add(WIFI_AP_SSID);
    cmbComPort.ItemIndex := 0;
    cmbComPort.Enabled := False;
  finally
    cmbComPort.Items.EndUpdate;
  end;
end;

procedure TfrmMain.LoadLensComList;
var
  Reg: TRegistry;
  Names: TStringList;
  I: Integer;
  PortName: string;
  PreviousPort: string;
begin
  PreviousPort := cmbLensComPort.Text;

  cmbLensComPort.Items.BeginUpdate;
  try
    cmbLensComPort.Clear;

    Reg := TRegistry.Create;
    Names := TStringList.Create;
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;

      if Reg.OpenKeyReadOnly(
        'HARDWARE\DEVICEMAP\SERIALCOMM'
      ) then
      begin
        Reg.GetValueNames(Names);

        for I := 0 to Names.Count - 1 do
        begin
          PortName := Reg.ReadString(Names[I]);

          if cmbLensComPort.Items.IndexOf(
            PortName
          ) < 0 then
          begin
            cmbLensComPort.Items.Add(
              PortName
            );
          end;
        end;

        Reg.CloseKey;
      end;
    finally
      Names.Free;
      Reg.Free;
    end;

    cmbLensComPort.Sorted := True;

    if (PreviousPort <> '') and
       (PreviousPort <> 'Pilih COM Port') and
       (cmbLensComPort.Items.IndexOf(
          PreviousPort
        ) >= 0) then
    begin
      cmbLensComPort.ItemIndex :=
        cmbLensComPort.Items.IndexOf(
          PreviousPort
        );
    end
    else if cmbLensComPort.Items.Count > 0 then
    begin
      cmbLensComPort.ItemIndex := 0;
    end
    else
    begin
      cmbLensComPort.ItemIndex := -1;
      cmbLensComPort.Text := 'Pilih COM Port';
    end;

  finally
    cmbLensComPort.Items.EndUpdate;
  end;
end;

procedure TfrmMain.btnRefreshComClick(Sender: TObject);
begin
  if MainConnectionConnected then
  begin
    ShowMessage(
      'Putuskan koneksi WiFi ESP32 A sebelum memperbarui informasi.'
    );
    Exit;
  end;

  LoadComList;

  SetStatus(
    'Pastikan laptop terhubung ke WiFi ' + WIFI_AP_SSID +
    ', kemudian tekan Hubungkan'
  );
end;

procedure TfrmMain.btnRefreshLensComClick(
  Sender: TObject
);
begin
  if SerialBackupConnected then
  begin
    ShowMessage(
      'Putuskan koneksi COM cadangan ESP32 A sebelum ' +
      'memperbarui daftar COM.'
    );

    Exit;
  end;

  LoadLensComList;

  if cmbLensComPort.ItemIndex >= 0 then
  begin
    SetStatus(
      'COM cadangan ESP32 A terdeteksi: ' +
      cmbLensComPort.Text
    );
  end
  else
  begin
    SetStatus(
      'COM cadangan ESP32 A tidak terdeteksi'
    );
  end;
end;

{ ============================================================================
  KONEKSI REVOLVER MELALUI ESP32 A
  WiFi utama dan COM cadangan memakai protokol yang sama.
  ============================================================================ }

function TfrmMain.LensCommandChannelAvailable: Boolean;
begin
  Result := SystemConnectionConnected;
end;

function TfrmMain.LensCommandUsesPrimary: Boolean;
begin
  { Bila jalur WiFi ESP32 A tersedia, jalur tersebut selalu diprioritaskan. }
  Result := MainConnectionConnected;
end;

function TfrmMain.SendLensCommand(
  const ACommand: string
): Boolean;
begin
  Result := False;

  if not LensCommandChannelAvailable then
  begin
    SetStatus('ESP32 A belum terhubung melalui WiFi maupun COM');
    Exit;
  end;

  { ESP32 B tidak pernah dihubungkan langsung ke Delphi.
    Semua perintah revolver selalu diteruskan oleh ESP32 A. }
  Result := SendCommand('REV=' + ACommand);

  if Result then
  begin
    FLensDirectBackupMode := not MainConnectionConnected;

    if MainConnectionConnected then
    begin
      SetStatus(
        'Perintah revolver dikirim melalui WiFi ESP32 A: ' +
        ACommand
      );
    end
    else
    begin
      SetStatus(
        'Perintah revolver dikirim melalui COM cadangan ESP32 A: ' +
        ACommand
      );
    end;
  end;
end;

procedure TfrmMain.ConfirmInitialLens4X;
var
  Answer: Integer;
begin
  if not LensCommandChannelAvailable then
    Exit;

  Answer := MessageDlg(
    'Konfirmasi posisi awal revolver objektif:' +
    sLineBreak + sLineBreak +
    'YES  = revolver saat ini berada pada Objektif 4×.' +
    sLineBreak +
    'NO   = revolver saat ini berada pada Objektif 10× ' +
    'dan sistem akan mengembalikannya otomatis ke 4×.' +
    sLineBreak + sLineBreak +
    'Apakah posisi objektif saat ini sudah 4×?',
    mtConfirmation,
    [mbYes, mbNo],
    0
  );

  if Answer = mrYes then
  begin
    FRecoverInitialLensFrom10X := False;

    if SendLensCommand('CONFIRM_4X') then
    begin
      FLensInitialPositionConfirmed := True;
      FLensMoving := False;
      FLensStopRequested := False;
      FLensActive := 1;
      FLensTarget := 1;

      lblActiveLensValue.Caption := 'Objektif 4×';

      { WiFi maupun COM cadangan sama-sama terhubung ke ESP32 A,
        sehingga profil Z tetap harus disinkronkan. }
      FZProfileSynchronized := False;
      lblLensMovementState.Caption :=
        'Sinkronisasi profil Z 4×';

      UpdateLensControlState;
      UpdateMotorControlState;
      StartZProfileSync;
    end
    else
    begin
      FLensInitialPositionConfirmed := False;
      FLensMoving := False;
      FLensStopRequested := False;
      FLensActive := 0;
      FZProfileSynchronized := False;

      lblActiveLensValue.Caption := 'Belum dikonfirmasi';
      lblLensMovementState.Caption := 'Gagal mengirim konfirmasi';

      UpdateLensControlState;
    end;
  end
  else
  begin
    { Pemulihan otomatis dapat memakai WiFi atau USB Serial,
      asalkan keduanya menuju ESP32 A. }
    if not SystemConnectionConnected then
    begin
      ShowMessage(
        'Hubungkan ESP32 A melalui WiFi atau COM cadangan ' +
        'sebelum menjalankan pemulihan 10× ke 4×.'
      );
      Exit;
    end;

    FRecoverInitialLensFrom10X := True;
    FLensInitialPositionConfirmed := False;
    FLensMoving := False;
    FLensStopRequested := False;
    FLensActive := 2;
    FLensTarget := 1;
    FLensChangeState := lcsIdle;
    FZProfileSynchronized := False;

    lblActiveLensValue.Caption :=
      'Objektif 10× (diasumsikan)';
    lblLensMovementState.Caption :=
      'Pemulihan otomatis ke 4×';

    UpdateLensControlState;
    UpdateMotorControlState;

    SetStatus(
      'Posisi awal diasumsikan 10×. Mengamankan sumbu Z ' +
      'sebelum kembali ke Objektif 4×.'
    );

    StartLensSafetySequence;
  end;
end;

procedure TfrmMain.btnConnectLensClick(
  Sender: TObject
);
begin
  if FAutoFocusRunning or FDualAutoFocusActive then
  begin
    ShowMessage(
      'Hentikan Autofokus sebelum mengubah koneksi COM cadangan.'
    );
    Exit;
  end;

  if FLensChangeState <> lcsIdle then
  begin
    ShowMessage(
      'Tunggu sampai rangkaian perpindahan objektif selesai.'
    );
    Exit;
  end;

  try
    if SerialBackupConnected then
    begin
      StopLensVerificationTimer;
      ComPortLens.Close;
      FLensSerialBuffer := '';
      SetLensConnectionState(False);

      if MainConnectionConnected then
        SetStatus('COM cadangan ESP32 A terputus; WiFi tetap aktif')
      else
        SetStatus('COM cadangan ESP32 A terputus');

      Exit;
    end;

    if cmbLensComPort.ItemIndex < 0 then
    begin
      ShowMessage(
        'Pilih COM port USB milik ESP32 A terlebih dahulu.'
      );
      Exit;
    end;

    ComPortLens.Port := cmbLensComPort.Text;
    ComPortLens.BaudRate := br115200;
    FLensSerialBuffer := '';
    ComPortLens.Open;

    SetLensConnectionState(True);

    if MainConnectionConnected then
    begin
      { WiFi tetap menjadi jalur utama. PING ini dikirim langsung melalui
        COM hanya untuk memastikan port cadangan benar-benar dapat ditulis. }
      ComPortLens.WriteStr('PING' + #13#10);
      FLensDirectBackupMode := False;

      SetStatus(
        'COM cadangan ESP32 A terhubung melalui ' +
        ComPortLens.Port + '; WiFi tetap menjadi jalur utama'
      );
    end
    else
    begin
      FLensDirectBackupMode := True;

      SetStatus(
        'ESP32 A terhubung melalui COM cadangan ' +
        ComPortLens.Port
      );

      { Sinkronkan seluruh status sistem melalui jalur serial ESP32 A. }
      SendCommand('PING');
      SendCommand('GETPOS');
      SendCommand('GETPROFILE');
      SendLensCommand('PING');
      SendLensCommand('GETLENS');

      if not FLensInitialPositionConfirmed then
        ConfirmInitialLens4X;
    end;

    UpdateAllControlStates;

  except
    on E: Exception do
    begin
      if SerialBackupConnected then
      begin
        try
          ComPortLens.Close;
        except
        end;
      end;

      FLensSerialBuffer := '';
      SetLensConnectionState(False);
      SetStatus('Gagal membuka COM cadangan ESP32 A');

      ShowMessage(
        'Gagal membuka COM port ESP32 A.' +
        sLineBreak +
        'Pastikan kabel USB terhubung ke ESP32 A dan ' +
        'Serial Monitor Arduino IDE sudah ditutup.' +
        sLineBreak +
        'Detail: ' + E.Message
      );
    end;
  end;
end;

{ ============================================================================
  KONTROL OBJEKTIF, PENGAMANAN Z, DAN PROFIL - LANGKAH 69
  ============================================================================ }

procedure TfrmMain.AbortLensChange(
  const AReason: string;
  AShowMessage: Boolean
);
begin
  StopLensVerificationTimer;
  FLensChangeState := lcsIdle;
  FLensTarget := 0;
  FRecoverInitialLensFrom10X := False;
  FLensMoving := False;
  FLensStopRequested := False;
  FPendingMotor := pmNone;

  if LensCommandChannelAvailable and
     FLensInitialPositionConfirmed then
  begin
    lblLensMovementState.Caption :=
      'Siap';
  end
  else
  begin
    lblLensMovementState.Caption :=
      'Tidak siap';
  end;

  UpdateLensControlState;
  UpdateMotorControlState;
  SetStatus(AReason);

  if FDualAutoFocusActive then
  begin
    FDualAutoFocusActive := False;
    FDualAutoFocusStopRequested := False;
    FDualAutoFocusStage := dafsIdle;
    FDualWinnerLens := 0;
    lblScanStageValue.Caption := 'Gagal';
    UpdateAllControlStates;
  end;

  if AShowMessage then
    ShowMessage(AReason);
end;

function TfrmMain.ExpectedMacroMaxForLens(
  ALens: Integer
): Integer;
begin
  case ALens of
    1:
      Result := MACRO_MAX_4X;

    2:
      Result := MACRO_MAX_10X;
  else
    Result := 0;
  end;
end;

function TfrmMain.ActiveMacroMaximum: Integer;
begin
  if FZProfileSynchronized and
     (
       (FZProfileMacroMax = MACRO_MAX_10X) or
       (FZProfileMacroMax = MACRO_MAX_4X)
     ) then
  begin
    Result := FZProfileMacroMax;
    Exit;
  end;

  if FZProfileReceived and
     FZProfileMacroMaxReceived and
     (
       (FZProfileMacroMax = MACRO_MAX_10X) or
       (FZProfileMacroMax = MACRO_MAX_4X)
     ) then
  begin
    Result := FZProfileMacroMax;
    Exit;
  end;

  Result := MACRO_MAX_4X;
end;

procedure TfrmMain.ApplyActiveMacroRange;
var
  ActiveMax: Integer;
  TargetValue: Integer;
begin
  ActiveMax := ActiveMacroMaximum;

  if (ActiveMax <> MACRO_MAX_10X) and
     (ActiveMax <> MACRO_MAX_4X) then
  begin
    ActiveMax := MACRO_MAX_4X;
  end;

  FAutoFocusMacroEnd := ActiveMax;

  { Grafik Makro real-time mengikuti profil aktif. }
  if Assigned(chtFocus) then
  begin
    chtFocus.BottomAxis.Automatic := False;
    chtFocus.BottomAxis.Minimum := MACRO_MIN_POS;
    chtFocus.BottomAxis.Maximum := ActiveMax;
    chtFocus.BottomAxis.Increment := 500;
  end;

  if Assigned(chtOtsu) then
  begin
    chtOtsu.BottomAxis.Automatic := False;
    chtOtsu.BottomAxis.Minimum := MACRO_MIN_POS;
    chtOtsu.BottomAxis.Maximum := ActiveMax;
    chtOtsu.BottomAxis.Increment := 500;
  end;

  { Grafik hasil 4× dan 10× mempunyai batas tetap masing-masing. }
  if Assigned(chtFocusMacro4XResult) then
  begin
    chtFocusMacro4XResult.BottomAxis.Automatic := False;
    chtFocusMacro4XResult.BottomAxis.Minimum := MACRO_MIN_POS;
    chtFocusMacro4XResult.BottomAxis.Maximum := MACRO_MAX_4X;
  end;

  if Assigned(chtOtsuMacro4XResult) then
  begin
    chtOtsuMacro4XResult.BottomAxis.Automatic := False;
    chtOtsuMacro4XResult.BottomAxis.Minimum := MACRO_MIN_POS;
    chtOtsuMacro4XResult.BottomAxis.Maximum := MACRO_MAX_4X;
  end;

  if Assigned(chtFocusMacro10XResult) then
  begin
    chtFocusMacro10XResult.BottomAxis.Automatic := False;
    chtFocusMacro10XResult.BottomAxis.Minimum := MACRO_MIN_POS;
    chtFocusMacro10XResult.BottomAxis.Maximum := MACRO_MAX_10X;
  end;

  if Assigned(chtOtsuMacro10XResult) then
  begin
    chtOtsuMacro10XResult.BottomAxis.Automatic := False;
    chtOtsuMacro10XResult.BottomAxis.Minimum := MACRO_MIN_POS;
    chtOtsuMacro10XResult.BottomAxis.Maximum := MACRO_MAX_10X;
  end;

  { Target lama dari profil 4× tidak boleh tertinggal saat masuk 10×. }
  if Assigned(edtMacroTarget) and
     TryStrToInt(Trim(edtMacroTarget.Text), TargetValue) and
     (TargetValue > ActiveMax) then
  begin
    edtMacroTarget.Text := IntToStr(ActiveMax);
  end;
end;

procedure TfrmMain.FailZProfileSync(
  const AReason: string;
  AShowMessage: Boolean
);
begin
  FLensChangeState := lcsIdle;
  FLensMoving := False;
  FLensStopRequested := False;
  FLensTarget := 0;
  FZProfileSynchronized := False;
  FZProfileDoneReceived := False;

  lblLensMovementState.Caption :=
    'Profil Z belum sinkron';

  UpdateLensControlState;
  UpdateMotorControlState;
  SetStatus(AReason);

  if FDualAutoFocusActive then
  begin
    FDualAutoFocusActive := False;
    FDualAutoFocusStopRequested := False;
    FDualAutoFocusStage := dafsIdle;
    FDualWinnerLens := 0;
    lblScanStageValue.Caption := 'Gagal';
    UpdateAllControlStates;
  end;

  if AShowMessage then
    ShowMessage(
      AReason + sLineBreak + sLineBreak +
      'Kontrol motor Z dan Autofokus dikunci sampai ' +
      'profil objektif berhasil disinkronkan.'
    );
end;

procedure TfrmMain.CompleteZProfileSync;
var
  LensName: string;
begin
  case FLensActive of
    1: LensName := '4×';
    2: LensName := '10×';
  else
    LensName := '?';
  end;

  FZProfileSynchronized := True;

  ApplyActiveMacroRange;

  FLensChangeState := lcsIdle;
  FLensTarget := 0;
  FLensMoving := False;
  FLensStopRequested := False;

  lblLensMovementState.Caption := 'Siap';

  UpdateLensControlState;
  UpdateMotorControlState;

  SetStatus(
    'Sinkronisasi selesai: Objektif ' + LensName +
    ', batas Makrometer ' + IntToStr(FZProfileMacroMax)
  );

  if FDualAutoFocusActive then
    ContinueDualAutoFocusAfterLensReady;
end;

procedure TfrmMain.EvaluateZProfileStatus;
var
  ExpectedLens: Integer;
  ExpectedMax: Integer;
  ProfileMatches: Boolean;
begin
  if not FZProfileReceived or
     not FZProfileMacroMaxReceived then
    Exit;

  ExpectedLens := FLensTarget;
  if ExpectedLens = 0 then
    ExpectedLens := FLensActive;

  if ExpectedLens = 0 then
    Exit;

  ExpectedMax := ExpectedMacroMaxForLens(ExpectedLens);
  ProfileMatches :=
    (FZProfileActive = ExpectedLens) and
    (FZProfileMacroMax = ExpectedMax);

  if FLensChangeState = lcsSyncZProfile then
  begin
    if not FZProfileDoneReceived then
      Exit;

    if ProfileMatches then
      CompleteZProfileSync
    else
      FailZProfileSync(
        'Balasan profil ESP32 sumbu Z tidak sesuai ' +
        'dengan objektif yang aktif.',
        True
      );
    Exit;
  end;

  if FLensInitialPositionConfirmed then
  begin
    if ProfileMatches then
    begin
      FZProfileSynchronized := True;

      ApplyActiveMacroRange;

      lblLensMovementState.Caption := 'Siap';
      UpdateLensControlState;
      UpdateMotorControlState;
      SetStatus(
        'Profil ESP32 sumbu Z sesuai dengan objektif aktif'
      );
    end
    else if SystemConnectionConnected and
            (FMacroPosition = 0) and
            (FMicroPosition = 0) then
    begin
      FLensTarget := FLensActive;
      StartZProfileSync;
    end
    else
    begin
      FZProfileSynchronized := False;
      lblLensMovementState.Caption :=
        'Profil Z tidak sesuai';
      UpdateLensControlState;
      UpdateMotorControlState;
      SetStatus(
        'Profil ESP32 Z tidak sesuai dan posisi Z belum aman 0'
      );
    end;
  end;
end;

procedure TfrmMain.StartZProfileSync;
var
  TargetLens: Integer;
  CommandText: string;
  LensName: string;
begin
  TargetLens := FLensTarget;
  if TargetLens = 0 then
    TargetLens := FLensActive;

  if not (TargetLens in [1, 2]) then
  begin
    FailZProfileSync('Target profil ESP32 Z tidak valid.', True);
    Exit;
  end;

  if not SystemConnectionConnected then
  begin
    FailZProfileSync('ESP32 A belum terhubung melalui WiFi maupun COM.', True);
    Exit;
  end;

  if (FMacroPosition <> 0) or (FMicroPosition <> 0) then
  begin
    FailZProfileSync(
      'Profil Z tidak dapat diganti karena Makrometer dan ' +
      'Mikrometer belum berada pada posisi 0.',
      True
    );
    Exit;
  end;

  case TargetLens of
    1:
      begin
        CommandText := 'PROFILE=4X';
        LensName := '4×';
      end;
    2:
      begin
        CommandText := 'PROFILE=10X';
        LensName := '10×';
      end;
  end;

  FLensTarget := TargetLens;
  FLensChangeState := lcsSyncZProfile;
  FLensMoving := False;
  FLensStopRequested := False;

  FZProfileReceived := False;
  FZProfileMacroMaxReceived := False;
  FZProfileDoneReceived := False;
  FZProfileSynchronized := False;

  lblLensMovementState.Caption :=
    'Sinkronisasi profil Z ' + LensName;

  UpdateLensControlState;
  UpdateMotorControlState;

  SetStatus('Mengirim ' + CommandText + ' ke ESP32 sumbu Z');

  if not SendCommand(CommandText) then
    FailZProfileSync(
      'Gagal mengirim ' + CommandText + ' ke ESP32 sumbu Z.',
      True
    );
end;

procedure TfrmMain.StartLensObjectiveMove;
var
  TargetName: string;
  CommandText: string;
begin
  if not LensCommandChannelAvailable then
  begin
    AbortLensChange(
      'Jalur komunikasi revolver terputus sebelum motor bergerak.',
      True
    );
    Exit;
  end;

  if SystemConnectionConnected and
     ((FMacroPosition <> 0) or (FMicroPosition <> 0)) then
  begin
    AbortLensChange(
      'Perpindahan lensa dibatalkan karena posisi Z belum mencapai 0.',
      True
    );
    Exit;
  end;

  case FLensTarget of
    1:
      begin
        TargetName := 'Objektif 4×';

        if FRecoverInitialLensFrom10X then
          CommandText := 'RECOVER_4X_FROM_10X'
        else
          CommandText := 'LENS=4X';
      end;

    2:
      begin
        TargetName := 'Objektif 10×';
        CommandText := 'LENS=10X';
      end;
  else
    AbortLensChange('Target objektif tidak valid.', True);
    Exit;
  end;

  FLensChangeState := lcsMoveObjective;
  FLensMoving := True;
  FLensStopRequested := False;
  FZProfileSynchronized := False;

  lblLensMovementState.Caption := 'Menuju ' + TargetName;

  UpdateLensControlState;
  UpdateMotorControlState;

  if LensCommandUsesPrimary then
    SetStatus('Posisi Z aman. Menggerakkan revolver menuju ' + TargetName)
  else
    SetStatus('COM cadangan ESP32 A: menggerakkan revolver menuju ' + TargetName);

  if not SendLensCommand(CommandText) then
  begin
    AbortLensChange(
      'Gagal mengirim perintah perpindahan lensa.',
      True
    );
  end
  else
  begin
    StartLensVerificationTimer;
  end;
end;

procedure TfrmMain.StartLensSafetySequence;
begin
  if FLensTarget = 0 then
  begin
    AbortLensChange(
      'Target objektif belum ditentukan.',
      True
    );
    Exit;
  end;

  { Tahap pertama: Mikrometer dikembalikan ke posisi tengah 0. }
  if FMicroPosition <> 0 then
  begin
    FLensChangeState := lcsMoveMicroZero;
    FPendingMotor := pmMicro;

    lblLensMovementState.Caption :=
      'Mengamankan Mikro ke 0';

    UpdateLensControlState;
    UpdateMotorControlState;

    SetStatus(
      'Pengamanan lensa: Mikrometer otomatis menuju posisi 0'
    );

    if not SendMicroTarget(0) then
    begin
      AbortLensChange(
        'Gagal menggerakkan Mikrometer menuju posisi aman 0.',
        True
      );
    end;

    Exit;
  end;

  { Tahap kedua: Makrometer diturunkan ke posisi paling aman 0. }
  if FMacroPosition <> 0 then
  begin
    FLensChangeState := lcsMoveMacroZero;
    FPendingMotor := pmMacro;

    lblLensMovementState.Caption :=
      'Mengamankan Makro ke 0';

    UpdateLensControlState;
    UpdateMotorControlState;

    SetStatus(
      'Pengamanan lensa: Makrometer otomatis menuju posisi 0'
    );

    if not SendMacroTarget(0) then
    begin
      AbortLensChange(
        'Gagal menggerakkan Makrometer menuju posisi aman 0.',
        True
      );
    end;

    Exit;
  end;

  { Makro dan Mikro sudah aman. Revolver baru boleh bergerak. }
  StartLensObjectiveMove;
end;

procedure TfrmMain.ContinueLensSafetyAfterMotorDone(
  AMotor: TPendingMotor
);
begin
  if FDualAutoFocusActive and
     FDualAutoFocusStopRequested then
  begin
    FLensChangeState := lcsIdle;
    FLensTarget := 0;
    FPendingMotor := pmNone;
    FLensMoving := False;
    FLensStopRequested := False;
    CancelDualAutoFocus(
      'Autofokus otomatis dihentikan setelah gerakan pengamanan Z selesai.'
    );
    Exit;
  end;

  case FLensChangeState of
    lcsMoveMicroZero:
      begin
        if AMotor <> pmMicro then
        begin
          AbortLensChange(
            'Motor yang selesai tidak sesuai dengan tahap pengamanan Mikro.',
            True
          );
          Exit;
        end;

        FMicroPosition := 0;

        lblMicroCurrentPosition.Caption :=
          '0 langkah';

        lblMicroPositionValue.Caption :=
          'Mikro: 0';

        edtMicroTarget.Text := '0';

        FPendingMotor := pmNone;

        SetStatus(
          'Mikrometer sudah di posisi aman 0'
        );

        { Setelah Mikro 0, lanjutkan Makro 0 atau langsung revolver. }
        StartLensSafetySequence;
      end;

    lcsMoveMacroZero:
      begin
        if AMotor <> pmMacro then
        begin
          AbortLensChange(
            'Motor yang selesai tidak sesuai dengan tahap pengamanan Makro.',
            True
          );
          Exit;
        end;

        FMacroPosition := 0;

        lblMacroCurrentPosition.Caption :=
          '0 langkah';

        lblMacroPositionValue.Caption :=
          'Makro: 0';

        edtMacroTarget.Text := '0';

        FPendingMotor := pmNone;

        SetStatus(
          'Makrometer sudah di posisi aman 0'
        );

        { Setelah Makro 0, revolver objektif boleh bergerak. }
        StartLensSafetySequence;
      end;
  else
    AbortLensChange(
      'State pengamanan lensa tidak sesuai saat motor Z selesai.',
      True
    );
  end;
end;

procedure TfrmMain.RequestLensChange(
  ATargetLens: Integer;
  AInternalDualAutoFocus: Boolean
);
var
  TargetName: string;
begin
  if not LensCommandChannelAvailable then
  begin
    ShowMessage(
      'Hubungkan ESP32 A melalui WiFi atau COM cadangan terlebih dahulu.'
    );
    Exit;
  end;

  if not FLensInitialPositionConfirmed then
  begin
    ShowMessage(
      'Posisi awal Objektif 4× belum dikonfirmasi.' +
      sLineBreak +
      'Pastikan revolver berada di 4×, lalu lakukan konfirmasi awal.'
    );
    Exit;
  end;

  if (FLensChangeState <> lcsIdle) or FLensMoving then
  begin
    ShowMessage('Rangkaian perpindahan objektif masih berlangsung.');
    Exit;
  end;

  { Perpindahan manual tetap dilarang selama Autofokus berlangsung.
    Namun Autofokus dua objektif harus diizinkan mengganti lensa
    melalui pemanggilan internal setelah scan Makro selesai. }
  if FAutoFocusRunning or
     (FDualAutoFocusActive and
      (not AInternalDualAutoFocus)) then
  begin
    ShowMessage('Hentikan Autofokus sebelum mengganti objektif.');
    Exit;
  end;

  if (FPendingMotor <> pmNone) or FGraphSamplePending then
  begin
    ShowMessage(
      'Tunggu sampai gerakan motor Z atau pengambilan sampel selesai.'
    );
    Exit;
  end;

  case ATargetLens of
    1: TargetName := 'Objektif 4×';
    2: TargetName := 'Objektif 10×';
  else
    ShowMessage('Target objektif tidak valid.');
    Exit;
  end;

  if FLensActive = ATargetLens then
  begin
    ShowMessage(TargetName + ' sudah aktif.');
    Exit;
  end;

  FLensTarget := ATargetLens;
  FLensDirectBackupMode := not MainConnectionConnected;

  { Baik WiFi maupun COM cadangan menuju ESP32 A. Karena itu urutan
    pengamanan Mikro 0 -> Makro 0 -> revolver selalu dijalankan. }
  SetStatus(
    'Memulai perpindahan ke ' + TargetName +
    ': posisi Z akan diamankan terlebih dahulu'
  );

  StartLensSafetySequence;
end;

procedure TfrmMain.btnLens4XClick(
  Sender: TObject
);
begin
  RequestLensChange(1);
end;

procedure TfrmMain.btnLens10XClick(
  Sender: TObject
);
begin
  RequestLensChange(2);
end;

procedure TfrmMain.btnStopLensClick(
  Sender: TObject
);
begin
  if not LensCommandChannelAvailable then
  begin
    ShowMessage('Jalur komunikasi revolver belum tersedia.');
    Exit;
  end;

  if not FLensMoving or
     (FLensChangeState <> lcsMoveObjective) then
  begin
    ShowMessage('Motor revolver lensa sedang tidak bergerak.');
    Exit;
  end;

  if FLensStopRequested then
    Exit;

  FLensStopRequested := True;
  lblLensMovementState.Caption := 'Menghentikan...';
  UpdateLensControlState;
  SetStatus('Mengirim perintah STOP ke revolver');

  if not SendLensCommand('STOP') then
  begin
    FLensStopRequested := False;
    UpdateLensControlState;
  end;
end;

{ ============================================================================
  HUBUNGKAN DAN PUTUSKAN ESP32
  ============================================================================ }

procedure TfrmMain.btnConnectClick(Sender: TObject);
begin
  if FAutoFocusRunning or FDualAutoFocusActive then
  begin
    ShowMessage(
      'Hentikan Autofokus sebelum memutuskan koneksi ESP32.'
    );
    Exit;
  end;

  if FLensChangeState <> lcsIdle then
  begin
    ShowMessage(
      'Tunggu sampai rangkaian perpindahan objektif selesai ' +
      'sebelum memutuskan koneksi ESP32 sumbu Z.'
    );
    Exit;
  end;

  try
    if MainConnectionConnected then
    begin
      DisconnectTcpClient('ESP32 A terputus dari WiFi TCP');
      FSerialBuffer := '';

      SetConnectionState(False);

      if SerialBackupConnected then
      begin
        FLensDirectBackupMode := True;
        SetStatus(
          'WiFi ESP32 A terputus; komunikasi dilanjutkan melalui COM cadangan'
        );
      end
      else
      begin
        FPendingMotor := pmNone;
        FZProfileSynchronized := False;
        SetStatus('ESP32 A terputus dari WiFi TCP');
      end;

      UpdateAllControlStates;
      Exit;
    end;

    InitializeTcpClient;

    IdTCPClient1.Connect;
    FWiFiConnected := IdTCPClient1.Connected;

    if not FWiFiConnected then
      raise Exception.Create('Socket TCP tidak dapat dibuka.');

    FTcpReceiveBuffer := '';

    if Assigned(FTcpReadTimer) then
      FTcpReadTimer.Enabled := True;

    FLensDirectBackupMode := False;
    SetConnectionState(True);

    SetStatus(
      'Terhubung ke ESP32 A melalui WiFi TCP ' +
      WIFI_TCP_HOST + ':' + IntToStr(WIFI_TCP_PORT)
    );

    { Protokol tetap sama seperti versi serial lama. }
    SendCommand('PING');
    SendCommand('GETPOS');
    SendCommand('GETPROFILE');
    SendLensCommand('PING');
    SendLensCommand('GETLENS');

    { Posisi fisik awal sistem wajib 4× seperti rancangan sebelumnya. }
    if not FLensInitialPositionConfirmed then
      ConfirmInitialLens4X;

  except
    on E: Exception do
    begin
      DisconnectTcpClient('');
      FPendingMotor := pmNone;
      SetConnectionState(False);
      SetStatus('Gagal terhubung ke ESP32 A melalui WiFi');

      ShowMessage(
        'Gagal membuka koneksi WiFi TCP ke ESP32 A.' +
        sLineBreak + sLineBreak +
        'Pastikan laptop sudah terhubung ke WiFi ' +
        WIFI_AP_SSID + '.' + sLineBreak +
        'Alamat: ' + WIFI_TCP_HOST + ':' +
        IntToStr(WIFI_TCP_PORT) + sLineBreak + sLineBreak +
        'Detail: ' + E.Message
      );
    end;
  end;
end;

{ ============================================================================
  PENGIRIMAN PERINTAH
  ============================================================================ }

function TfrmMain.SendCommand(
  const ACommand: string
): Boolean;
var
  UseWiFi: Boolean;
begin
  Result := False;

  if not SystemConnectionConnected then
  begin
    SetStatus('ESP32 A belum terhubung melalui WiFi maupun COM');
    Exit;
  end;

  UseWiFi := MainConnectionConnected;

  try
    if UseWiFi then
    begin
      { WiFi menjadi prioritas apabila kedua jalur tersambung. }
      IdTCPClient1.IOHandler.WriteLn(ACommand);
      FLensDirectBackupMode := False;
    end
    else
    begin
      { COM cadangan terhubung ke USB Serial ESP32 A, bukan ESP32 B. }
      ComPortLens.WriteStr(ACommand + #13#10);
      FLensDirectBackupMode := True;
    end;

    Result := True;
  except
    on E: Exception do
    begin
      if UseWiFi then
      begin
        DisconnectTcpClient('');
        SetConnectionState(False);
        SetStatus('Gagal mengirim perintah melalui WiFi TCP');
      end
      else
      begin
        if SerialBackupConnected then
        begin
          try
            ComPortLens.Close;
          except
          end;
        end;

        SetLensConnectionState(False);
        SetStatus('Gagal mengirim perintah melalui COM cadangan ESP32 A');
      end;

      { Perintah tidak dikirim ulang otomatis ke jalur lain karena dapat
        menyebabkan gerakan motor yang sama dijalankan dua kali. }
      ShowMessage(
        'Gagal mengirim perintah ke ESP32 A.' +
        sLineBreak +
        'Perintah: ' + ACommand + sLineBreak +
        'Perintah tidak dikirim ulang otomatis demi keamanan motor.' +
        sLineBreak +
        'Detail: ' + E.Message
      );
    end;
  end;
end;

function TfrmMain.SendMacroTarget(
  ATarget: Integer
): Boolean;
var
  ActiveMax: Integer;
begin
  ActiveMax := ActiveMacroMaximum;

  if (ATarget < MACRO_MIN_POS) or
     (ATarget > ActiveMax) then
  begin
    Result := False;

    SetStatus(
      'Target Makrometer ' +
      IntToStr(ATarget) +
      ' ditolak. Batas profil aktif adalah ' +
      IntToStr(ActiveMax) +
      '.'
    );

    Exit;
  end;

  Result := SendCommand(
    'MACRO=' + IntToStr(ATarget)
  );
end;

function TfrmMain.SendMicroTarget(
  ATarget: Integer
): Boolean;
begin
  Result := SendCommand(
    'MICRO=' + IntToStr(ATarget)
  );
end;

{ ============================================================================
  KONTROL MANUAL MAKROMETER
  ============================================================================ }

procedure TfrmMain.btnMoveMacroClick(Sender: TObject);
var
  Target: Integer;
  ActiveMax: Integer;
begin
  if not SystemConnectionConnected then
  begin
    ShowMessage('ESP32 A belum terhubung melalui WiFi maupun COM.');
    Exit;
  end;

  if FLensInitialPositionConfirmed and
     (not FZProfileSynchronized) then
  begin
    ShowMessage('Profil objektif ESP32 sumbu Z belum sinkron.');
    Exit;
  end;

  if FPendingMotor <> pmNone then
  begin
    ShowMessage('Motor masih menjalankan perintah sebelumnya.');
    Exit;
  end;

  if not TryStrToInt(
    Trim(edtMacroTarget.Text),
    Target
  ) then
  begin
    ShowMessage('Target Makrometer harus berupa angka.');
    edtMacroTarget.SetFocus;
    Exit;
  end;

  ActiveMax := ActiveMacroMaximum;

  if (Target < MACRO_MIN_POS) or
     (Target > ActiveMax) then
  begin
    ShowMessage(
      'Target Makrometer harus berada pada rentang 0 sampai ' +
      IntToStr(ActiveMax) +
      ' untuk profil objektif yang sedang aktif.'
    );

    edtMacroTarget.SetFocus;
    Exit;
  end;

  FPendingMotor := pmMacro;
  UpdateMotorControlState;

  SetStatus(
    'Menggerakkan Makrometer dari ' +
    IntToStr(FMacroPosition) +
    ' ke ' +
    IntToStr(Target)
  );

  if not SendMacroTarget(Target) then
  begin
    FPendingMotor := pmNone;
    UpdateMotorControlState;
  end;
end;

{ ============================================================================
  KONTROL MANUAL MIKROMETER
  ============================================================================ }

procedure TfrmMain.btnMoveMicroClick(Sender: TObject);
var
  Target: Integer;
begin
  if not SystemConnectionConnected then
  begin
    ShowMessage('ESP32 A belum terhubung melalui WiFi maupun COM.');
    Exit;
  end;

  if FLensInitialPositionConfirmed and
     (not FZProfileSynchronized) then
  begin
    ShowMessage('Profil objektif ESP32 sumbu Z belum sinkron.');
    Exit;
  end;

  if FPendingMotor <> pmNone then
  begin
    ShowMessage('Motor masih menjalankan perintah sebelumnya.');
    Exit;
  end;

  if not TryStrToInt(
    Trim(edtMicroTarget.Text),
    Target
  ) then
  begin
    ShowMessage('Target Mikrometer harus berupa angka.');
    edtMicroTarget.SetFocus;
    Exit;
  end;

  if (Target < MICRO_MIN_POS) or
     (Target > MICRO_MAX_POS) then
  begin
    ShowMessage(
      'Target Mikrometer harus berada pada rentang -1600 sampai 1600.'
    );

    edtMicroTarget.SetFocus;
    Exit;
  end;

  FPendingMotor := pmMicro;
  UpdateMotorControlState;

  SetStatus(
    'Menggerakkan Mikrometer dari ' +
    IntToStr(FMicroPosition) +
    ' ke ' +
    IntToStr(Target)
  );

  if not SendMicroTarget(Target) then
  begin
    FPendingMotor := pmNone;
    UpdateMotorControlState;
  end;
end;

{procedure TfrmMain.btnPengaturanKameraClick(Sender: TObject);
begin

end;

 ============================================================================
  INPUT KEYBOARD TARGET MOTOR
  ============================================================================ }

procedure TfrmMain.edtMacroTargetKeyPress(
  Sender: TObject;
  var Key: Char
);
begin
  if not (Key in ['0'..'9', #8, #13]) then
    Key := #0;

  if Key = #13 then
  begin
    Key := #0;
    btnMoveMacro.Click;
  end;
end;

procedure TfrmMain.edtMicroTargetKeyPress(
  Sender: TObject;
  var Key: Char
);
var
  EditControl: TEdit;
begin
  EditControl := TEdit(Sender);

  if Key in ['0'..'9', #8, #13] then
  begin
    if Key = #13 then
    begin
      Key := #0;
      btnMoveMicro.Click;
    end;

    Exit;
  end;

  if Key in ['-', '+'] then
  begin
    if (EditControl.SelStart <> 0) or
       (Pos('-', EditControl.Text) > 0) or
       (Pos('+', EditControl.Text) > 0) then
    begin
      Key := #0;
    end;

    Exit;
  end;

  Key := #0;
end;

{ ============================================================================
  PENERIMAAN DATA SERIAL
  ============================================================================ }

procedure TfrmMain.ComPort1RxChar(
  Sender: TObject;
  Count: Integer
);
var
  DataMasuk: string;
  Baris: string;
  PosNewLine: Integer;
begin
  ComPort1.ReadStr(DataMasuk, Count);

  if DataMasuk = '' then
    Exit;

  FSerialBuffer := FSerialBuffer + DataMasuk;

  PosNewLine := Pos(#10, FSerialBuffer);

  while PosNewLine > 0 do
  begin
    Baris := Copy(
      FSerialBuffer,
      1,
      PosNewLine - 1
    );

    Delete(
      FSerialBuffer,
      1,
      PosNewLine
    );

    Baris := StringReplace(
      Baris,
      #13,
      '',
      [rfReplaceAll]
    );

    ProcessSerialLine(Baris);

    PosNewLine := Pos(#10, FSerialBuffer);
  end;
end;

{ ============================================================================
  PENERIMAAN DATA SERIAL CADANGAN ESP32 A
  ============================================================================ }

procedure TfrmMain.ComPortLensRxChar(
  Sender: TObject;
  Count: Integer
);
var
  DataMasuk: string;
  Baris: string;
  PosNewLine: Integer;
begin
  ComPortLens.ReadStr(DataMasuk, Count);

  if DataMasuk = '' then
    Exit;

  FLensSerialBuffer := FLensSerialBuffer + DataMasuk;
  PosNewLine := Pos(#10, FLensSerialBuffer);

  while PosNewLine > 0 do
  begin
    Baris := Copy(FLensSerialBuffer, 1, PosNewLine - 1);
    Delete(FLensSerialBuffer, 1, PosNewLine);
    Baris := StringReplace(Baris, #13, '', [rfReplaceAll]);

    Baris := Trim(Baris);

    { ESP32 A mengirim balasan yang sama ke TCP dan USB Serial.
      Saat WiFi aktif, data COM diabaikan agar tidak diproses dua kali.
      Saat WiFi mati, COM menjadi jalur aktif dan seluruh baris diproses
      oleh parser utama ESP32 A. }
    if (Baris <> '') and (not MainConnectionConnected) then
      ProcessSerialLine(Baris);

    PosNewLine := Pos(#10, FLensSerialBuffer);
  end;
end;

procedure TfrmMain.StopLensVerificationTimer;
begin
  if Assigned(FLensVerifyTimer) then
    FLensVerifyTimer.Enabled := False;
end;

procedure TfrmMain.StartLensVerificationTimer;
begin
  FLensVerifyRetryCount := 0;

  if not Assigned(FLensVerifyTimer) then
    Exit;

  FLensVerifyTimer.Enabled := False;
  FLensVerifyTimer.Interval :=
    LENS_VERIFY_FIRST_DELAY_MS;
  FLensVerifyTimer.Enabled := True;
end;

procedure TfrmMain.LensVerifyTimerTick(
  Sender: TObject
);
begin
  StopLensVerificationTimer;

  if (FLensChangeState <> lcsMoveObjective) or
     (not FLensMoving) then
    Exit;

  if not LensCommandChannelAvailable then
  begin
    AbortLensChange(
      'Jalur komunikasi revolver terputus saat menunggu status akhir.',
      True
    );
    Exit;
  end;

  Inc(FLensVerifyRetryCount);

  if FLensVerifyRetryCount >
     LENS_VERIFY_MAX_RETRY then
  begin
    AbortLensChange(
      'Objektif sudah bergerak, tetapi Delphi tidak menerima ' +
      'balasan posisi akhir dari ESP32 lensa.' +
      sLineBreak +
      'Putuskan lalu hubungkan kembali ESP32 lensa.',
      True
    );
    Exit;
  end;

  SetStatus(
    'Memeriksa ulang posisi objektif melalui GETLENS ' +
    '(' +
    IntToStr(FLensVerifyRetryCount) +
    '/' +
    IntToStr(LENS_VERIFY_MAX_RETRY) +
    ')'
  );

  if not SendLensCommand('GETLENS') then
  begin
    AbortLensChange(
      'Gagal meminta status objektif dari ESP32 lensa.',
      True
    );
    Exit;
  end;

  FLensVerifyTimer.Interval :=
    LENS_VERIFY_RETRY_DELAY_MS;
  FLensVerifyTimer.Enabled := True;
end;

procedure TfrmMain.CompleteLensMovement(
  AConfirmedLens: Integer
);
var
  LensName: string;
begin
  if not (AConfirmedLens in [1, 2]) then
    Exit;

  StopLensVerificationTimer;

  FLensActive := AConfirmedLens;
  FLensTarget := AConfirmedLens;
  FLensInitialPositionConfirmed := True;
  FRecoverInitialLensFrom10X := False;
  FLensMoving := False;
  FLensStopRequested := False;

  case AConfirmedLens of
    1: LensName := '4×';
    2: LensName := '10×';
  end;

  lblActiveLensValue.Caption := 'Objektif ' + LensName;

  if FLensChangeState = lcsMoveObjective then
  begin
    if SystemConnectionConnected then
    begin
      lblLensMovementState.Caption :=
        'Sinkronisasi profil Z ' + LensName;

      UpdateLensControlState;
      UpdateMotorControlState;

      SetStatus(
        'Objektif ' + LensName +
        ' terkonfirmasi. Menyinkronkan profil ESP32 sumbu Z.'
      );

      StartZProfileSync;
    end;
  end
  else
  begin
    if FZProfileSynchronized then
      lblLensMovementState.Caption := 'Siap'
    else
      lblLensMovementState.Caption :=
        'Menunggu profil Z ' + LensName;

    UpdateLensControlState;
    UpdateMotorControlState;
  end;
end;

procedure TfrmMain.ProcessLensSerialLine(
  const ALine: string
);
var
  Line: string;
  UpperLine: string;
begin
  Line := Trim(ALine);
  if Line = '' then Exit;
  UpperLine := UpperCase(Line);

  if SameText(Line, 'READY') or
     SameText(Line, 'LENS_CONTROLLER_READY') or
     SameText(Line, 'LENS_READY') then
  begin
    SetStatus('ESP32 pemilih lensa siap');
    Exit;
  end;

  if SameText(Line, 'PONG') then
  begin
    SetStatus('Komunikasi ESP32 pemilih lensa berhasil');
    Exit;
  end;

  if SameText(Line, 'LENS_MOVING=4X') then
  begin
    FLensChangeState := lcsMoveObjective;
    FLensMoving := True;
    FLensStopRequested := False;
    FZProfileSynchronized := False;
    lblLensMovementState.Caption := 'Bergerak menuju 4×';
    UpdateLensControlState;
    UpdateMotorControlState;
    SetStatus('Revolver bergerak menuju Objektif 4×');
    Exit;
  end;

  if SameText(Line, 'LENS_MOVING=10X') then
  begin
    FLensChangeState := lcsMoveObjective;
    FLensMoving := True;
    FLensStopRequested := False;
    FZProfileSynchronized := False;
    lblLensMovementState.Caption := 'Bergerak menuju 10×';
    UpdateLensControlState;
    UpdateMotorControlState;
    SetStatus('Revolver bergerak menuju Objektif 10×');
    Exit;
  end;

  if SameText(Line, 'LENS=4X') then
  begin
    CompleteLensMovement(1);
    Exit;
  end;

  if SameText(Line, 'LENS=10X') then
  begin
    CompleteLensMovement(2);
    Exit;
  end;

  if SameText(Line, 'LENS_DONE') then
  begin
    StopLensVerificationTimer;

    if FLensChangeState = lcsSyncZProfile then
      Exit;

    if FLensTarget in [1, 2] then
    begin
      CompleteLensMovement(FLensTarget);
    end
    else
    begin
      AbortLensChange(
        'ESP32 mengirim LENS_DONE tetapi target objektif tidak diketahui.',
        True
      );
    end;

    Exit;
  end;

  if SameText(Line, 'LENS_ALREADY=4X') then
  begin
    FLensInitialPositionConfirmed := True;
    FLensMoving := False;
    FLensStopRequested := False;
    FLensActive := 1;
    FLensTarget := 1;
    FZProfileSynchronized := False;
    lblActiveLensValue.Caption := 'Objektif 4×';
    lblLensMovementState.Caption := 'Sinkronisasi profil Z 4×';
    StartZProfileSync;
    Exit;
  end;

  if SameText(Line, 'LENS_ALREADY=10X') then
  begin
    FLensInitialPositionConfirmed := True;
    FLensMoving := False;
    FLensStopRequested := False;
    FLensActive := 2;
    FLensTarget := 2;
    FZProfileSynchronized := False;
    lblActiveLensValue.Caption := 'Objektif 10×';
    lblLensMovementState.Caption := 'Sinkronisasi profil Z 10×';
    StartZProfileSync;
    Exit;
  end;

  if SameText(Line, 'STOP_OK') then
  begin
    FLensStopRequested := True;
    lblLensMovementState.Caption := 'Menghentikan...';
    UpdateLensControlState;
    SetStatus('ESP32 menerima perintah STOP');
    Exit;
  end;

  if SameText(Line, 'LENS_STOPPED') then
  begin
    StopLensVerificationTimer;
    FLensMoving := False;
    FLensStopRequested := False;
    FLensInitialPositionConfirmed := False;
    FLensActive := 0;
    FRecoverInitialLensFrom10X := False;
    FLensChangeState := lcsIdle;
    FLensTarget := 0;
    FZProfileSynchronized := False;

    if FDualAutoFocusActive then
    begin
      FDualAutoFocusActive := False;
      FDualAutoFocusStopRequested := False;
      FDualAutoFocusStage := dafsIdle;
      FDualWinnerLens := 0;
      lblScanStageValue.Caption := 'Dihentikan';
    end;

    lblActiveLensValue.Caption := 'Tidak diketahui';
    lblLensMovementState.Caption := 'Dihentikan';
    UpdateLensControlState;
    UpdateMotorControlState;
    SetStatus('Motor lensa dihentikan; posisi objektif tidak diketahui');
    ShowMessage(
      'Pergerakan lensa telah dihentikan.' + sLineBreak + sLineBreak +
      'Posisi objektif sekarang tidak diketahui.' + sLineBreak +
      'Putuskan koneksi, posisikan revolver secara fisik ' +
      'pada Objektif 4×, lalu hubungkan kembali.'
    );
    Exit;
  end;

  if SameText(Line, 'LENS=UNKNOWN') then
  begin
    StopLensVerificationTimer;
    FLensMoving := False;
    FLensStopRequested := False;
    FLensInitialPositionConfirmed := False;
    FLensActive := 0;
    FRecoverInitialLensFrom10X := False;
    FLensChangeState := lcsIdle;
    FLensTarget := 0;
    FZProfileSynchronized := False;

    if FDualAutoFocusActive then
    begin
      FDualAutoFocusActive := False;
      FDualAutoFocusStopRequested := False;
      FDualAutoFocusStage := dafsIdle;
      FDualWinnerLens := 0;
      lblScanStageValue.Caption := 'Dihentikan';
    end;

    lblActiveLensValue.Caption := 'Tidak diketahui';
    lblLensMovementState.Caption := 'Perlu konfirmasi 4×';
    UpdateLensControlState;
    UpdateMotorControlState;
    SetStatus('Posisi objektif belum diketahui');
    Exit;
  end;

  if SameText(Line, 'MOTOR_NOT_MOVING') then
  begin
    FLensMoving := False;
    FLensStopRequested := False;
    FLensChangeState := lcsIdle;
    FLensTarget := 0;
    lblLensMovementState.Caption := 'Tidak bergerak';
    UpdateLensControlState;
    UpdateMotorControlState;
    SetStatus('Motor lensa sedang tidak bergerak');
    Exit;
  end;

  if SameText(Line, 'ERROR_RECOVERY_NOT_SUPPORTED') then
  begin
    AbortLensChange(
      'Firmware ESP32 lensa belum mendukung pemulihan otomatis ' +
      'dari 10× ke 4×. Upload firmware Langkah 76 terlebih dahulu.',
      True
    );
    Exit;
  end;

  if SameText(Line, 'ERROR_CONFIRM_4X_FIRST') then
  begin
    FLensMoving := False;
    FLensStopRequested := False;
    FLensInitialPositionConfirmed := False;
    FLensActive := 0;
    FRecoverInitialLensFrom10X := False;
    FLensChangeState := lcsIdle;
    FLensTarget := 0;
    FZProfileSynchronized := False;
    lblActiveLensValue.Caption := 'Belum dikonfirmasi';
    lblLensMovementState.Caption := 'Konfirmasi 4× diperlukan';
    UpdateLensControlState;
    UpdateMotorControlState;
    ShowMessage(
      'ESP32 menolak perpindahan karena posisi awal 4× ' +
      'belum dikonfirmasi.'
    );
    Exit;
  end;

  if Pos('BUSY_IGNORED=', UpperLine) = 1 then
  begin
    AbortLensChange(
      'ESP32 lensa masih sibuk dan mengabaikan perintah: ' + Line,
      True
    );
    Exit;
  end;

  if Pos('UNKNOWN_COMMAND=', UpperLine) = 1 then
  begin
    AbortLensChange(
      'Perintah ESP32 lensa tidak dikenal: ' + Line,
      True
    );
    Exit;
  end;

  if Pos('ERROR', UpperLine) = 1 then
  begin
    AbortLensChange(
      'ESP32 lensa melaporkan kesalahan: ' + Line,
      True
    );
    Exit;
  end;

  SetStatus('ESP32 lensa: ' + Line);
end;

{ ============================================================================
  PEMROSESAN BALASAN ESP32
  ============================================================================ }

procedure TfrmMain.ProcessSerialLine(
  const ALine: string
);
var
  Line: string;
  UpperLine: string;
  RevolverLine: string;
  NilaiText: string;
  Nilai: Integer;
begin
  Line := Trim(ALine);

  if Line = '' then
    Exit;

  UpperLine := UpperCase(Line);

  { ESP32 A meneruskan seluruh balasan ESP32 B dengan awalan REV_RX=. }
  if Pos('REV_RX=', UpperLine) = 1 then
  begin
    RevolverLine := Copy(Line, Length('REV_RX=') + 1, MaxInt);
    ProcessLensSerialLine(RevolverLine);
    Exit;
  end;

  { REV_TX hanya log bahwa ESP32 A meneruskan perintah. }
  if Pos('REV_TX=', UpperLine) = 1 then
  begin
    SetStatus('ESP32 A meneruskan: ' +
      Copy(Line, Length('REV_TX=') + 1, MaxInt));
    Exit;
  end;

  if SameText(Line, 'Z_MOVEMENT_LOCKED_BY_REVOLVER') then
  begin
    FLensMoving := True;
    FZProfileSynchronized := False;
    UpdateAllControlStates;
    SetStatus('Gerakan sumbu Z dikunci selama revolver bergerak');
    Exit;
  end;

  if SameText(Line, 'Z_MOVEMENT_UNLOCKED') then
  begin
    FLensMoving := False;
    UpdateAllControlStates;
    SetStatus('Gerakan sumbu Z dibuka kembali');
    Exit;
  end;

  if Pos('PROFILE_SYNC=', UpperLine) = 1 then
  begin
    FZProfileDoneReceived := True;
    SetStatus('Profil Z disinkronkan otomatis: ' +
      Copy(Line, Length('PROFILE_SYNC=') + 1, MaxInt));
    Exit;
  end;

  if SameText(Line, 'ERROR_LENS_CHANGE_NOT_SAFE') then
  begin
    AbortLensChange(
      'ESP32 A menolak perpindahan lensa karena posisi Z belum aman 0.',
      True
    );
    Exit;
  end;

  if SameText(Line, 'ERROR_REVOLVER_BUSY') or
     SameText(Line, 'ERROR_Z_LOCKED_REVOLVER_MOVING') then
  begin
    SetStatus('Perintah ditolak karena revolver masih bergerak');
    Exit;
  end;

  if SameText(Line, 'Z_MOVEMENT_LOCKED_LENS_UNKNOWN') or
     SameText(Line, 'PROFILE_SYNC_BLOCKED_LENS_UNKNOWN') then
  begin
    FLensInitialPositionConfirmed := False;
    FLensActive := 0;
    FZProfileSynchronized := False;
    lblActiveLensValue.Caption := 'Tidak diketahui';
    lblLensMovementState.Caption := 'Konfirmasi 4× diperlukan';
    UpdateAllControlStates;
    SetStatus('Posisi lensa tidak diketahui; kontrol Z dikunci');
    Exit;
  end;

  if SameText(Line, 'PONG') then
  begin
    SetStatus('Komunikasi ESP32 berhasil');
    Exit;
  end;

  if SameText(Line, 'READY') then
  begin
    SetStatus('ESP32 siap digunakan');

    FZProfileReceived := False;
    FZProfileMacroMaxReceived := False;
    FZProfileDoneReceived := False;
    FZProfileSynchronized := False;

    if SystemConnectionConnected then
    begin
      SendCommand('GETPOS');
      SendCommand('GETPROFILE');
      SendLensCommand('PING');
      SendLensCommand('GETLENS');
    end;

    Exit;
  end;

  if SameText(Line, 'PROFILE=4X') then
  begin
    FZProfileActive := 1;
    FZProfileReceived := True;
    FZProfileMacroMaxReceived := False;

    SetStatus('ESP32 Z melaporkan profil Objektif 4×');
    EvaluateZProfileStatus;
    Exit;
  end;

  if SameText(Line, 'PROFILE=10X') then
  begin
    FZProfileActive := 2;
    FZProfileReceived := True;
    FZProfileMacroMaxReceived := False;

    SetStatus('ESP32 Z melaporkan profil Objektif 10×');
    EvaluateZProfileStatus;
    Exit;
  end;

  if Pos('MACRO_MAX=', Line) = 1 then
  begin
    NilaiText := Copy(Line, Length('MACRO_MAX=') + 1, MaxInt);
    if TryStrToInt(Trim(NilaiText), Nilai) then
    begin
      FZProfileMacroMax := Nilai;
      FZProfileMacroMaxReceived := True;
      SetStatus('Batas Makrometer profil aktif: ' + IntToStr(Nilai));
      EvaluateZProfileStatus;
    end;
    Exit;
  end;

  if SameText(Line, 'PROFILE_DONE') or
     SameText(Line, 'PROFILE_ALREADY_ACTIVE') then
  begin
    FZProfileDoneReceived := True;
    EvaluateZProfileStatus;
    Exit;
  end;

  if SameText(Line, 'ERROR_PROFILE_CHANGE_NOT_SAFE') then
  begin
    FailZProfileSync(
      'ESP32 sumbu Z menolak perubahan profil karena ' +
      'Makrometer atau Mikrometer belum berada pada posisi 0.',
      True
    );
    Exit;
  end;

  if SameText(Line, 'ERROR_HOME_ONLY_4X') then
  begin
    SetStatus('Homing ditolak: hanya diizinkan pada profil 4×');
    Exit;
  end;

  if SameText(Line, 'ERROR_MACRO_LIMIT_10X') then
  begin
    if FAutoFocusRunning then
    begin
      AbortAutoFocus(
        'Autofokus dibatalkan: target Makrometer melampaui ' +
        'batas profil 10× yaitu 3200.'
      );
    end
    else
    begin
      SetStatus(
        'Target Makrometer ditolak: batas profil 10× adalah 3200'
      );
    end;

    Exit;
  end;

  if SameText(Line, 'ERROR_MACRO_LIMIT_4X') then
  begin
    if FAutoFocusRunning then
    begin
      AbortAutoFocus(
        'Autofokus dibatalkan: target Makrometer melampaui ' +
        'batas profil 4× yaitu 3800.'
      );
    end
    else
    begin
      SetStatus(
        'Target Makrometer ditolak: batas profil 4× adalah 3800'
      );
    end;

    Exit;
  end;

  if SameText(Line, 'ERROR_MACRO_BELOW_MIN') then
  begin
    if FAutoFocusRunning then
    begin
      AbortAutoFocus(
        'Autofokus dibatalkan: target Makrometer kurang dari 0.'
      );
    end
    else
    begin
      SetStatus(
        'Target Makrometer ditolak: nilai tidak boleh kurang dari 0'
      );
    end;

    Exit;
  end;

  if Pos('POS_MACRO=', Line) = 1 then
  begin
    NilaiText := Copy(
      Line,
      Length('POS_MACRO=') + 1,
      MaxInt
    );

    if TryStrToInt(Trim(NilaiText), Nilai) then
    begin
      FMacroPosition := Nilai;

      lblMacroCurrentPosition.Caption :=
        IntToStr(Nilai) + ' langkah';

      lblMacroPositionValue.Caption :=
        'Makro: ' + IntToStr(Nilai);

      UpdateLensControlState;
    end;

    Exit;
  end;

  if Pos('POS_MICRO=', Line) = 1 then
  begin
    NilaiText := Copy(
      Line,
      Length('POS_MICRO=') + 1,
      MaxInt
    );

    if TryStrToInt(Trim(NilaiText), Nilai) then
    begin
      FMicroPosition := Nilai;

      lblMicroCurrentPosition.Caption :=
        IntToStr(Nilai) + ' langkah';

      lblMicroPositionValue.Caption :=
        'Mikro: ' + IntToStr(Nilai);

      UpdateLensControlState;
    end;

    Exit;
  end;

  if Pos('MACRO_TARGET=', Line) = 1 then
  begin
    NilaiText := Copy(
      Line,
      Length('MACRO_TARGET=') + 1,
      MaxInt
    );

    SetStatus(
      'ESP32 menggerakkan Makrometer ke ' +
      Trim(NilaiText)
    );

    Exit;
  end;

  if Pos('MICRO_TARGET=', Line) = 1 then
  begin
    NilaiText := Copy(
      Line,
      Length('MICRO_TARGET=') + 1,
      MaxInt
    );

    SetStatus(
      'ESP32 menggerakkan Mikrometer ke ' +
      Trim(NilaiText)
    );

    Exit;
  end;

  if SameText(Line, 'MACRO_DONE') then
  begin
    FPendingMotor := pmNone;

    if FLensChangeState = lcsMoveMacroZero then
    begin
      ContinueLensSafetyAfterMotorDone(pmMacro);
    end
    else if FAutoFocusRunning then
      HandleAutoFocusMotorDone(pmMacro)
    else if FCameraActive then
      StartGraphSampling(pmMacro, FMacroPosition)
    else
    begin
      UpdateMotorControlState;

      SetStatus(
        'Pergerakan Makrometer selesai pada posisi ' +
        IntToStr(FMacroPosition)
      );
    end;

    Exit;
  end;

  if SameText(Line, 'MICRO_DONE') then
  begin
    FPendingMotor := pmNone;

    if FLensChangeState = lcsMoveMicroZero then
    begin
      ContinueLensSafetyAfterMotorDone(pmMicro);
    end
    else if FAutoFocusRunning then
      HandleAutoFocusMotorDone(pmMicro)
    else if FCameraActive then
      StartGraphSampling(pmMicro, FMicroPosition)
    else
    begin
      UpdateMotorControlState;

      SetStatus(
        'Pergerakan Mikrometer selesai pada posisi ' +
        IntToStr(FMicroPosition)
      );
    end;

    Exit;
  end;

  if SameText(Line, 'MACRO_LIMIT_STOP') then
  begin
    FPendingMotor := pmNone;

    if FLensChangeState = lcsMoveMacroZero then
    begin
      FMacroPosition := 0;

      lblMacroCurrentPosition.Caption :=
        '0 langkah';

      lblMacroPositionValue.Caption :=
        'Makro: 0';

      edtMacroTarget.Text := '0';

      ContinueLensSafetyAfterMotorDone(pmMacro);
    end
    else if FAutoFocusRunning then
    begin
      case FAutoFocusPhase of
        afpMacroScan:
          begin
            if (FAutoFocusState = afsMoving) and
               (FAutoFocusCurrentTarget = AUTOFOCUS_MACRO_START) then
            begin
              FMacroPosition := AUTOFOCUS_MACRO_START;

              lblMacroCurrentPosition.Caption :=
                IntToStr(FMacroPosition) + ' langkah';

              lblMacroPositionValue.Caption :=
                'Makro: ' + IntToStr(FMacroPosition);

              FAutoFocusState := afsSampling;

              lblScanStageValue.Caption :=
                'Mengukur batas bawah Makro';

              SetStatus(
                'Limit bawah Makrometer tercapai. ' +
                'Posisi ditetapkan sebagai 0 dan sampel diambil.'
              );

              BeginSettledSampling(pmMacro);
            end
            else if FAutoFocusPointsDone > 0 then
            begin
              FAutoFocusTotalPoints :=
                FAutoFocusPointsDone +
                FMacroCandidateCount +
                (((AUTOFOCUS_MICRO_END - AUTOFOCUS_MICRO_START) div
                  AUTOFOCUS_MICRO_COARSE_STEP) + 1) +
                (((AUTOFOCUS_MICRO_FINE_HALF_RANGE * 2) div
                  AUTOFOCUS_MICRO_FINE_STEP) + 1) +
                AUTOFOCUS_CANDIDATE_COUNT;

              UpdateAutoFocusProgress;

              lblScanStageValue.Caption :=
                'Batas atas Makro tercapai';

              SetStatus(
                'Limit atas Makrometer tercapai. ' +
                'Kembali ke posisi Makrometer terbaik ' +
                IntToStr(FAutoFocusBestMacroPosition) + '.'
              );

              StartMacroVerification;
            end
            else
              AbortAutoFocus(
                'Limit Makrometer tercapai sebelum data fokus diperoleh.'
              );
          end;

        afpMacroVerify:
          AbortAutoFocus(
            'Limit Makrometer aktif saat verifikasi kandidat.'
          );

        afpMacroReturn:
          begin
            if FAutoFocusState = afsReadyReturn then
              SetStatus(
                'Batas Makrometer selesai diproses. ' +
                'Menyiapkan gerakan kembali.'
              )
            else
              AbortAutoFocus(
                'Limit aktif saat Makrometer kembali ke posisi terbaik.'
              );
          end;
      else
        AbortAutoFocus(
          'Limit Makrometer aktif pada tahap yang tidak sesuai.'
        );
      end;
    end
    else
    begin
      UpdateMotorControlState;
      SetStatus('Makrometer dihentikan oleh limit switch');
    end;

    Exit;
  end;

  if SameText(Line, 'MICRO_LIMIT_STOP') then
  begin
    FPendingMotor := pmNone;

    if FLensChangeState = lcsMoveMicroZero then
    begin
      AbortLensChange(
        'Mikrometer menyentuh limit saat menuju posisi aman 0.',
        True
      );
    end
    else if FAutoFocusRunning then
    begin
      case FAutoFocusPhase of
        afpPrepareMicroCenter:
          AbortAutoFocus(
            'Limit Mikrometer aktif saat menuju posisi tengah 0.'
          );

        afpMicroCoarseScan:
          begin
            if (FAutoFocusState = afsMoving) and
               (FAutoFocusCurrentTarget =
                AUTOFOCUS_MICRO_START) then
            begin
              FMicroPosition :=
                AUTOFOCUS_MICRO_START;

              lblMicroCurrentPosition.Caption :=
                IntToStr(FMicroPosition) +
                ' langkah';

              lblMicroPositionValue.Caption :=
                'Mikro: ' +
                IntToStr(FMicroPosition);

              lblScanStageValue.Caption :=
                'Batas bawah Mikro kasar';

              SetStatus(
                'Limit bawah Mikrometer tercapai. ' +
                'Mengambil sampel kasar pada -1600.'
              );

              BeginSettledSampling(pmMicro);
            end
            else if FAutoFocusBestMicroCoarseFocus >= 0 then
            begin
              SetStatus(
                'Limit atas Mikrometer tercapai pada scan kasar. ' +
                'Dilanjutkan ke scan halus.'
              );

              StartMicroFineScan;
            end
            else
            begin
              AbortAutoFocus(
                'Limit Mikrometer tercapai sebelum data kasar diperoleh.'
              );
            end;
          end;

        afpMicroFineScan:
          begin
            if (FAutoFocusState = afsMoving) and
               (FAutoFocusCurrentTarget =
                FAutoFocusMicroFineStart) then
            begin
              FMicroPosition :=
                FAutoFocusMicroFineStart;

              lblMicroCurrentPosition.Caption :=
                IntToStr(FMicroPosition) +
                ' langkah';

              lblMicroPositionValue.Caption :=
                'Mikro: ' +
                IntToStr(FMicroPosition);

              lblScanStageValue.Caption :=
                'Batas scan Mikro halus';

              SetStatus(
                'Batas Mikrometer tercapai pada awal scan halus. ' +
                'Sampel tetap diambil.'
              );

              BeginSettledSampling(pmMicro);
            end
            else if FAutoFocusBestMicroFocus >= 0 then
            begin
              FAutoFocusTotalPoints :=
                FAutoFocusPointsDone +
                FMicroCandidateCount;

              UpdateAutoFocusProgress;

              SetStatus(
                'Batas atas Mikrometer tercapai pada scan halus. ' +
                'Kandidat terbaik akan diverifikasi.'
              );

              StartMicroVerification;
            end
            else
            begin
              AbortAutoFocus(
                'Limit Mikrometer tercapai sebelum data halus diperoleh.'
              );
            end;
          end;

        afpMicroVerify:
          AbortAutoFocus(
            'Limit Mikrometer aktif saat verifikasi kandidat.'
          );

        afpMicroBacklashPrep:
          begin
            { Limit bawah boleh menjadi posisi pendekatan backlash. }
            FMicroPosition :=
              AUTOFOCUS_MICRO_START;

            lblMicroCurrentPosition.Caption :=
              IntToStr(FMicroPosition) +
              ' langkah';

            lblMicroPositionValue.Caption :=
              'Mikro: ' +
              IntToStr(FMicroPosition);

            FAutoFocusPhase :=
              afpMicroReturn;

            QueueAutoFocusMove(
              pmMicro,
              FAutoFocusBestMicroPosition,
              True
            );
          end;

        afpMicroReturn:
          AbortAutoFocus(
            'Limit aktif saat Mikrometer menuju posisi terbaik.'
          );
      else
        AbortAutoFocus(
          'Limit Mikrometer aktif pada tahap yang tidak sesuai.'
        );
      end;
    end
    else
    begin
      UpdateMotorControlState;
      SetStatus('Mikrometer dihentikan oleh limit switch');
    end;

    Exit;
  end;

  if SameText(Line, 'MACRO_STOPPED') or
     SameText(Line, 'MICRO_STOPPED') then
  begin
    FPendingMotor := pmNone;

    if FLensChangeState in [
      lcsMoveMicroZero,
      lcsMoveMacroZero
    ] then
    begin
      AbortLensChange(
        'Gerakan pengamanan posisi Z dihentikan oleh ESP32.',
        True
      );
    end
    else if FAutoFocusRunning then
    begin
      if (FAutoFocusState = afsReadyReturn) or
         (FAutoFocusState = afsSettling) or
         ((FAutoFocusState = afsSampling) and FGraphSamplePending) then
      begin
        SetStatus(
          'Gerakan pada batas mekanik selesai. ' +
          'Proses Autofokus dilanjutkan.'
        );
      end
      else
        AbortAutoFocus(
          'Gerakan motor dihentikan oleh ESP32.'
        );
    end
    else
    begin
      UpdateMotorControlState;
      SetStatus('Gerakan motor dihentikan');
    end;

    Exit;
  end;

  if SameText(Line, 'MACRO_TARGET_CLAMPED_MIN') or
     SameText(Line, 'MACRO_TARGET_CLAMPED_MAX') then
  begin
    SetStatus('Target Makrometer dibatasi oleh ESP32');
    Exit;
  end;

  if SameText(Line, 'MICRO_TARGET_CLAMPED_MIN') or
     SameText(Line, 'MICRO_TARGET_CLAMPED_MAX') then
  begin
    SetStatus('Target Mikrometer dibatasi oleh ESP32');
    Exit;
  end;

  if SameText(Line, 'ERROR_MACRO_VALUE') or
     SameText(Line, 'ERROR_MICRO_VALUE') then
  begin
    FPendingMotor := pmNone;

    if FLensChangeState in [
      lcsMoveMicroZero,
      lcsMoveMacroZero
    ] then
    begin
      AbortLensChange(
        'ESP32 menolak target posisi aman 0.',
        True
      );
    end
    else if FAutoFocusRunning then
    begin
      AbortAutoFocus(
        'ESP32 menolak target Autofokus.'
      );
    end
    else
    begin
      UpdateMotorControlState;
      SetStatus('ESP32 menolak nilai target motor');
    end;

    Exit;
  end;

  if Pos('BUSY_IGNORED=', Line) = 1 then
  begin
    FPendingMotor := pmNone;

    if FLensChangeState in [
      lcsMoveMicroZero,
      lcsMoveMacroZero
    ] then
    begin
      AbortLensChange(
        'Perintah pengamanan Z diabaikan karena ESP32 masih sibuk.',
        True
      );
    end
    else if FAutoFocusRunning then
    begin
      AbortAutoFocus(
        'Perintah Autofokus diabaikan karena ESP32 masih sibuk.'
      );
    end
    else
    begin
      UpdateMotorControlState;
      SetStatus('ESP32 masih menjalankan perintah sebelumnya');
    end;

    Exit;
  end;

  if SameText(Line, 'HOMING_UP') then
  begin
    SetStatus('Homing Makrometer: menuju limit atas');
    Exit;
  end;

  if SameText(Line, 'LIMIT_ATAS_HOME_OK') then
  begin
    SetStatus('Limit atas Makrometer tercapai');
    Exit;
  end;

  if SameText(Line, 'HOMING_DOWN') then
  begin
    SetStatus('Homing Makrometer: menuju limit bawah');
    Exit;
  end;

  if SameText(Line, 'HOME_OK') then
  begin
    SetStatus('Homing Makrometer selesai');
    Exit;
  end;

  if Pos('RESTORE_MACRO=', Line) = 1 then
  begin
    NilaiText := Copy(
      Line,
      Length('RESTORE_MACRO=') + 1,
      MaxInt
    );

    SetStatus(
      'Mengembalikan Makrometer ke posisi ' +
      Trim(NilaiText)
    );

    Exit;
  end;

  if SameText(Line, 'RESTORE_DONE') then
  begin
    SetStatus('Restore posisi Makrometer selesai');
    Exit;
  end;

  if SameText(Line, 'LIMIT_ATAS') then
  begin
    SetStatus('Limit atas aktif');
    Exit;
  end;

  if SameText(Line, 'LIMIT_BAWAH') then
  begin
    SetStatus('Limit bawah aktif');
    Exit;
  end;

  if SameText(Line, 'SYSTEM_ERROR_HOMING') or
     SameText(Line, 'ERROR_HOMING_ATAS') or
     SameText(Line, 'ERROR_HOMING_BAWAH') or
     SameText(Line, 'ERROR_BOTH_LIMITS') then
  begin
    FPendingMotor := pmNone;
    UpdateMotorControlState;
    SetStatus('Homing gagal: periksa limit switch');
    Exit;
  end;
end;

{ ============================================================================
  KAMERA NORMAL, GRAYSCALE, THRESHOLD MANUAL, DAN OTSU - TAHAP 7
  ============================================================================ }

procedure TfrmMain.InitializeCameraControls;
begin
  FCameraActive := False;
  FLastOtsu := 0;
  FLastFocus := 0;
  FFrameCounter := 0;

  FGraphActiveMotor := pmNone;
  ResetGraphSampling;

  cmbCamera.Clear;
  cmbCamera.Items.Add('0 - CAMERA DEFAULT / LAPTOP');
  cmbCamera.Items.Add('1 - CAMERA USB / EKSTERNAL');
  cmbCamera.Items.Add('2 - CAMERA LAINNYA');
  cmbCamera.ItemIndex := 0;

  btnStartCamera.Caption := 'Mulai Kamera';
  btnStopCamera.Caption := 'Hentikan';

  { Fitur pengaturan driver kamera belum tersedia pada jalur
    TocvCameraSource yang digunakan. Tombol tetap ditampilkan agar
    desain antarmuka tidak berubah, tetapi dinonaktifkan supaya pengguna
    tidak mengira fitur tersebut sudah dapat digunakan. }
  btnCameraSettings.Caption := 'Pengaturan Kamera';
  btnCameraSettings.Enabled := False;
  btnCameraSettings.ShowHint := True;
  btnCameraSettings.Hint :=
    'Fitur pengaturan kamera belum tersedia pada versi ini.';

  lblCameraState.Caption := 'Kamera tidak aktif';
  shpCameraStatus.Brush.Color := clSilver;

  ocvCameraSource1.Enabled := False;

  ocvImageOperation1.Enabled := True;
  ocvImageOperation1.VideoSource := nil;

  ocvImageOperation2.Enabled := True;
  ocvImageOperation2.VideoSource := nil;

  ocvView1.VideoSource := nil;
  ocvView1.Align := alClient;
  ocvView1.Visible := False;

  { Frame memenuhi seluruh area preview. }
  ocvView1.Proportional := False;

  pnlCameraViewHost.Color := clBlack;
  pnlCameraViewHost.Repaint;

  UpdateCameraControlState;
end;

procedure TfrmMain.SetSelectedCamera;
begin
  case cmbCamera.ItemIndex of
    0:
      ocvCameraSource1.Camera := CAP_CAM_0;

    1:
      ocvCameraSource1.Camera := CAP_CAM_1;

    2:
      ocvCameraSource1.Camera := CAP_CAM_2;

  else
    ocvCameraSource1.Camera := CAP_CAM_0;
  end;
end;

procedure TfrmMain.ConfigureGrayOperation;
begin
  ocvImageOperation1.Enabled := True;
  ocvImageOperation1.VideoSource := ocvCameraSource1;
  ocvImageOperation1.OperationClassName :=
    'TocvGrayScaleOperation';
end;

procedure TfrmMain.ConfigureThresholdOperation;
begin
  ConfigureGrayOperation;

  ocvImageOperation2.Enabled := True;
  ocvImageOperation2.VideoSource := ocvImageOperation1;
  ocvImageOperation2.OperationClassName :=
    'TocvThresholdOperation';

  UpdateThresholdManualOperation;
end;

procedure TfrmMain.UpdateThresholdManualOperation;
var
  ThresholdOperation: TocvThresholdOperation;
begin
  lblThresholdValue.Caption :=
    IntToStr(tbThreshold.Position);

  if ocvImageOperation2.Operation = nil then
    Exit;

  if not (
    ocvImageOperation2.Operation is TocvThresholdOperation
  ) then
    Exit;

  ThresholdOperation :=
    ocvImageOperation2.Operation as TocvThresholdOperation;

  ThresholdOperation.Threshold :=
    tbThreshold.Position;

  ThresholdOperation.MaxValue := 255;

  if chkInvertThreshold.Checked then
    ThresholdOperation.ThresholdType :=
      THRESH_BINARY_INV
  else
    ThresholdOperation.ThresholdType :=
      THRESH_BINARY;
end;

procedure TfrmMain.UpdateThresholdOtsuOperation;
var
  ThresholdOperation: TocvThresholdOperation;
begin
  if ocvImageOperation2.Operation = nil then
    Exit;

  if not (
    ocvImageOperation2.Operation is TocvThresholdOperation
  ) then
    Exit;

  ThresholdOperation :=
    ocvImageOperation2.Operation as TocvThresholdOperation;

  ThresholdOperation.Threshold := 0;
  ThresholdOperation.MaxValue := 255;
  ThresholdOperation.ThresholdType := THRESH_OTSU;
end;

procedure TfrmMain.SetupCamera;
begin
  { Putuskan semua jalur lama terlebih dahulu. }
  ocvCameraSource1.Enabled := False;

  ocvView1.VideoSource := nil;
  ocvImageOperation2.VideoSource := nil;
  ocvImageOperation1.VideoSource := nil;

  ocvView1.Visible := False;

  pnlCameraViewHost.Color := clBlack;
  pnlCameraViewHost.Repaint;
  Application.ProcessMessages;

  SetSelectedCamera;

  { Resolusi yang sudah berhasil pada Tahap 4 dan Tahap 5. }
  ocvCameraSource1.Resolution := r640x360;

  ConfigureGrayOperation;
  ConfigureThresholdOperation;

  ocvView1.Align := alClient;
  ocvView1.Proportional := False;
  ocvView1.Visible := True;
end;

procedure TfrmMain.ShowCameraNormal;
begin
  if not FCameraActive then
    Exit;

  ocvView1.VideoSource := nil;
  ocvView1.Repaint;
  Application.ProcessMessages;

  ocvView1.VideoSource := ocvCameraSource1;
  ocvView1.Visible := True;
  ocvView1.Repaint;

  SetStatus('Mode kamera: Normal');
end;

procedure TfrmMain.ShowCameraGrayScale;
begin
  if not FCameraActive then
    Exit;

  ConfigureGrayOperation;

  ocvView1.VideoSource := nil;
  ocvView1.Repaint;
  Application.ProcessMessages;

  ocvView1.VideoSource := ocvImageOperation1;
  ocvView1.Visible := True;
  ocvView1.Repaint;

  SetStatus('Mode kamera: Grayscale');
end;

procedure TfrmMain.ShowCameraThresholdManual;
begin
  if not FCameraActive then
    Exit;

  ConfigureThresholdOperation;

  ocvView1.VideoSource := nil;
  ocvView1.Repaint;
  Application.ProcessMessages;

  ocvView1.VideoSource := ocvImageOperation2;
  ocvView1.Visible := True;
  ocvView1.Repaint;

  SetStatus(
    'Mode kamera: Threshold Manual = ' +
    IntToStr(tbThreshold.Position)
  );
end;

procedure TfrmMain.ShowCameraThresholdOtsu;
begin
  if not FCameraActive then
    Exit;

  ConfigureThresholdOperation;
  UpdateThresholdOtsuOperation;

  ocvView1.VideoSource := nil;
  ocvView1.Repaint;
  Application.ProcessMessages;

  ocvView1.VideoSource := ocvImageOperation2;
  ocvView1.Visible := True;
  ocvView1.Repaint;

  SetStatus('Mode kamera: Threshold Otsu otomatis');
end;

procedure TfrmMain.ApplyCameraMode;
begin
  if not FCameraActive then
    Exit;

  if rbThresholdOtsu.Checked then
    ShowCameraThresholdOtsu
  else if rbThresholdManual.Checked then
    ShowCameraThresholdManual
  else if rbGrayscale.Checked then
    ShowCameraGrayScale
  else
    ShowCameraNormal;
end;

procedure TfrmMain.StartCamera;
begin
  if FCameraActive then
    Exit;

  try
    SetupCamera;

    FLastOtsu := 0;
    FLastFocus := 0;
    FFrameCounter := 0;

    FGraphActiveMotor := pmNone;
    ResetGraphSampling;
    ClearAllGraphSeries;

    lblCurrentOtsu.Caption := '0';
    lblCurrentFocus.Caption := '0,000';
    lblFocusInfo.Caption := 'menunggu frame';

    ocvCameraSource1.Enabled := True;
    FCameraActive := True;

    SetCameraState(True);
    ApplyCameraMode;

  except
    on E: Exception do
    begin
      try
        ocvCameraSource1.Enabled := False;
        ocvView1.VideoSource := nil;
        ocvImageOperation1.VideoSource := nil;
        ocvImageOperation2.VideoSource := nil;
        ocvView1.Visible := False;
      except
      end;

      FCameraActive := False;

      pnlCameraViewHost.Color := clBlack;
      pnlCameraViewHost.Repaint;

      SetCameraState(False);

      ShowMessage(
        'Gagal menjalankan kamera.' + sLineBreak +
        'Detail: ' + E.Message
      );
    end;
  end;
end;

procedure TfrmMain.StopCamera;
begin
  try
    ocvCameraSource1.Enabled := False;

    ocvView1.VideoSource := nil;
    ocvImageOperation2.VideoSource := nil;
    ocvImageOperation1.VideoSource := nil;

    ocvView1.Visible := False;

    FCameraActive := False;
    FLastOtsu := 0;
    FLastFocus := 0;
    FFrameCounter := 0;

    ResetGraphSampling;

    lblCurrentOtsu.Caption := '0';
    lblCurrentFocus.Caption := '0,000';
    lblFocusInfo.Caption := 'belum ada data';

    pnlCameraViewHost.Color := clBlack;
    pnlCameraViewHost.Repaint;

    SetCameraState(False);
    SetStatus('Kamera dihentikan');

  except
    on E: Exception do
    begin
      FCameraActive := False;
      SetCameraState(False);

      ShowMessage(
        'Gagal menghentikan kamera.' + sLineBreak +
        'Detail: ' + E.Message
      );
    end;
  end;
end;

procedure TfrmMain.SetCameraState(AActive: Boolean);
begin
  if AActive then
  begin
    lblCameraState.Caption := 'Kamera aktif';
    shpCameraStatus.Brush.Color := clLime;
  end
  else
  begin
    lblCameraState.Caption := 'Kamera tidak aktif';
    shpCameraStatus.Brush.Color := clSilver;
  end;

  UpdateCameraControlState;
  UpdateMotorControlState;
end;

procedure TfrmMain.UpdateCameraControlState;
var
  CameraLocked: Boolean;
begin
  CameraLocked :=
    FAutoFocusRunning or
    FDualAutoFocusActive;

  cmbCamera.Enabled :=
    (not FCameraActive) and
    (not CameraLocked);

  { Tombol pengaturan kamera sengaja selalu dinonaktifkan karena
    TocvCameraSource pada program ini belum menyediakan dialog pengaturan
    exposure, gain, white balance, dan properti driver kamera. }
  btnCameraSettings.Enabled := False;

  btnStartCamera.Enabled :=
    (not FCameraActive) and
    (not CameraLocked);

  btnStopCamera.Enabled :=
    FCameraActive and
    (not CameraLocked);

  if not rbNormal.Checked and
     not rbGrayscale.Checked and
     not rbThresholdManual.Checked and
     not rbThresholdOtsu.Checked then
  begin
    rbNormal.Checked := True;
  end;

  rbNormal.Enabled := not CameraLocked;
  rbGrayscale.Enabled := not CameraLocked;
  rbThresholdManual.Enabled := not CameraLocked;
  rbThresholdOtsu.Enabled := not CameraLocked;

  tbThreshold.Enabled :=
    rbThresholdManual.Checked and
    (not CameraLocked);

  chkInvertThreshold.Enabled :=
    rbThresholdManual.Checked and
    (not CameraLocked);

  if rbThresholdOtsu.Checked then
    lblThresholdValue.Caption := 'AUTO'
  else
    lblThresholdValue.Caption :=
      IntToStr(tbThreshold.Position);
end;

procedure TfrmMain.btnStartCameraClick(Sender: TObject);
begin
  StartCamera;
end;

procedure TfrmMain.btnStopCameraClick(Sender: TObject);
begin
  StopCamera;
end;

procedure TfrmMain.btnCameraSettingsClick(Sender: TObject);
begin
  { Prosedur ini tetap disediakan sebagai pengaman apabila event dipanggil
    melalui kode lain. Pada antarmuka, tombol selalu dinonaktifkan. }
  ShowMessage(
    'Fitur pengaturan kamera belum tersedia pada versi ini.' +
    sLineBreak +
    'Gunakan pengaturan bawaan driver atau aplikasi kamera apabila diperlukan.'
  );
end;

procedure TfrmMain.ProcessingModeClick(Sender: TObject);
begin
  UpdateCameraControlState;

  if FCameraActive then
  begin
    ApplyCameraMode;
  end
  else if rbThresholdOtsu.Checked then
  begin
    SetStatus(
      'Mode Threshold Otsu dipilih; tekan Mulai Kamera'
    );
  end
  else if rbThresholdManual.Checked then
  begin
    SetStatus(
      'Mode Threshold Manual dipilih; tekan Mulai Kamera'
    );
  end
  else if rbGrayscale.Checked then
  begin
    SetStatus(
      'Mode Grayscale dipilih; tekan Mulai Kamera'
    );
  end
  else
  begin
    SetStatus(
      'Mode Normal dipilih; tekan Mulai Kamera'
    );
  end;
end;

procedure TfrmMain.tbThresholdChange(Sender: TObject);
begin
  lblThresholdValue.Caption :=
    IntToStr(tbThreshold.Position);

  if rbThresholdManual.Checked then
  begin
    UpdateThresholdManualOperation;

    if FCameraActive then
    begin
      ocvView1.VideoSource := ocvImageOperation2;
      ocvView1.Repaint;

      SetStatus(
        'Threshold Manual: ' +
        IntToStr(tbThreshold.Position)
      );
    end;
  end;
end;

procedure TfrmMain.chkInvertThresholdClick(Sender: TObject);
begin
  if not rbThresholdManual.Checked then
    Exit;

  UpdateThresholdManualOperation;

  if FCameraActive then
  begin
    ocvView1.VideoSource := ocvImageOperation2;
    ocvView1.Repaint;

    if chkInvertThreshold.Checked then
      SetStatus('Inversi Threshold aktif')
    else
      SetStatus('Inversi Threshold tidak aktif');
  end;
end;

{ ============================================================================
  INISIALISASI MODE PEMROSESAN
  Tahap 7 mengaktifkan Normal, Grayscale, Threshold Manual, dan Otsu.
  ============================================================================ }

procedure TfrmMain.InitializeProcessingControls;
begin
  rbNormal.Checked := True;
  rbNormal.Enabled := True;

  rbGrayscale.Checked := False;
  rbGrayscale.Enabled := True;

  rbThresholdManual.Checked := False;
  rbThresholdManual.Enabled := True;

  rbThresholdOtsu.Checked := False;
  rbThresholdOtsu.Enabled := True;

  tbThreshold.Min := 0;
  tbThreshold.Max := 255;
  tbThreshold.Position := 127;
  tbThreshold.Enabled := False;

  chkInvertThreshold.Checked := False;
  chkInvertThreshold.Enabled := False;

  lblThresholdValue.Caption :=
    IntToStr(tbThreshold.Position);

  lblCurrentOtsu.Caption := '0';
  lblCurrentFocus.Caption := '0,000';

  lblOtsuInfo.Caption := 'threshold';
  lblFocusInfo.Caption := 'belum ada data';
end;

{ ============================================================================
  PERHITUNGAN OTSU DAN FOCUS SCORE REALTIME
  ============================================================================ }

function TfrmMain.AmbilGray(
  const Img: IocvImage;
  X, Y: Integer
): Byte;
var
  Pixel: TocvPixel;
  GrayValue: Integer;
begin
  Result := 0;

  if Img = nil then
    Exit;

  if (X < 0) or
     (Y < 0) or
     (X >= Img.Width) or
     (Y >= Img.Height) then
  begin
    Exit;
  end;

  Pixel := Img.Pixel[X, Y];

  if Img.isGray then
  begin
    Result := Pixel.GV;
  end
  else
  begin
    GrayValue := Round(
      (0.299 * Pixel.R) +
      (0.587 * Pixel.G) +
      (0.114 * Pixel.B)
    );

    if GrayValue < 0 then
      GrayValue := 0
    else if GrayValue > 255 then
      GrayValue := 255;

    Result := Byte(GrayValue);
  end;
end;

function TfrmMain.HitungOtsuDariImage(
  const Img: IocvImage
): Integer;
var
  Histogram: array[0..255] of Integer;
  X, Y: Integer;
  ThresholdValue: Integer;
  TotalPixel: Integer;
  BackgroundWeight: Integer;
  ForegroundWeight: Integer;
  TotalSum: Double;
  BackgroundSum: Double;
  BackgroundMean: Double;
  ForegroundMean: Double;
  BetweenVariance: Double;
  MaximumVariance: Double;
  GrayValue: Byte;
  PixelStep: Integer;
begin
  Result := 0;

  if Img = nil then
    Exit;

  if (Img.Width <= 0) or
     (Img.Height <= 0) then
  begin
    Exit;
  end;

  FillChar(Histogram, SizeOf(Histogram), 0);

  TotalPixel := 0;

  { Membaca setiap dua piksel agar perhitungan realtime tetap ringan. }
  PixelStep := 2;

  Y := 0;

  while Y < Img.Height do
  begin
    X := 0;

    while X < Img.Width do
    begin
      GrayValue := AmbilGray(Img, X, Y);

      Inc(Histogram[GrayValue]);
      Inc(TotalPixel);

      Inc(X, PixelStep);
    end;

    Inc(Y, PixelStep);
  end;

  if TotalPixel = 0 then
    Exit;

  TotalSum := 0;

  for ThresholdValue := 0 to 255 do
  begin
    TotalSum :=
      TotalSum +
      (ThresholdValue * Histogram[ThresholdValue]);
  end;

  BackgroundSum := 0;
  BackgroundWeight := 0;
  MaximumVariance := -1;

  for ThresholdValue := 0 to 255 do
  begin
    BackgroundWeight :=
      BackgroundWeight +
      Histogram[ThresholdValue];

    if BackgroundWeight = 0 then
      Continue;

    ForegroundWeight :=
      TotalPixel -
      BackgroundWeight;

    if ForegroundWeight = 0 then
      Break;

    BackgroundSum :=
      BackgroundSum +
      (ThresholdValue * Histogram[ThresholdValue]);

    BackgroundMean :=
      BackgroundSum /
      BackgroundWeight;

    ForegroundMean :=
      (TotalSum - BackgroundSum) /
      ForegroundWeight;

    BetweenVariance :=
      BackgroundWeight *
      ForegroundWeight *
      Sqr(BackgroundMean - ForegroundMean);

    if BetweenVariance > MaximumVariance then
    begin
      MaximumVariance := BetweenVariance;
      Result := ThresholdValue;
    end;
  end;
end;

function TfrmMain.HitungFocusScoreDariImage(
  const Img: IocvImage;
  AOtsuThreshold: Integer
): Double;
var
  X, Y: Integer;
  W, H: Integer;
  ROILeft: Integer;
  ROIRight: Integer;
  ROITop: Integer;
  ROIBottom: Integer;
  CenterValue: Integer;
  LeftValue: Integer;
  RightValue: Integer;
  TopValue: Integer;
  BottomValue: Integer;
  CenterClass: Boolean;
  IsObjectEdge: Boolean;
  GradientX: Integer;
  GradientY: Integer;
  LaplacianValue: Integer;
  EdgeCount: Integer;
  SumGradientSquare: Double;
  SumLaplacianSquare: Double;
  GradientRMS: Double;
  LaplacianRMS: Double;
  PixelStep: Integer;

  { Fallback apabila citra tidak mempunyai batas Otsu yang cukup. }
  FallbackCount: Integer;
  FallbackSum: Double;
begin
  Result := 0;

  if Img = nil then
    Exit;

  W := Img.Width;
  H := Img.Height;

  if (W < 5) or (H < 5) then
    Exit;

  { ROI diperlebar menjadi 80 persen area tengah. Berbeda dari Tahap 12
    yang hanya memakai 50 persen tengah, sehingga objek diagonal atau
    preparat yang sedikit bergeser tetap ikut dinilai. }
  ROILeft := W div 10;
  ROIRight := W - (W div 10) - 1;
  ROITop := H div 10;
  ROIBottom := H - (H div 10) - 1;

  if ROILeft < 1 then
    ROILeft := 1;

  if ROITop < 1 then
    ROITop := 1;

  if ROIRight > (W - 2) then
    ROIRight := W - 2;

  if ROIBottom > (H - 2) then
    ROIBottom := H - 2;

  PixelStep := 2;
  EdgeCount := 0;
  SumGradientSquare := 0;
  SumLaplacianSquare := 0;

  FallbackCount := 0;
  FallbackSum := 0;

  Y := ROITop;

  while Y <= ROIBottom do
  begin
    X := ROILeft;

    while X <= ROIRight do
    begin
      CenterValue := AmbilGray(Img, X, Y);
      LeftValue := AmbilGray(Img, X - 1, Y);
      RightValue := AmbilGray(Img, X + 1, Y);
      TopValue := AmbilGray(Img, X, Y - 1);
      BottomValue := AmbilGray(Img, X, Y + 1);

      CenterClass := CenterValue <= AOtsuThreshold;

      { Piksel hanya dinilai apabila berada pada batas hitam-putih
        hasil Otsu. Dengan demikian, tekstur dan noise latar tidak lagi
        mendominasi Focus Score. }
      IsObjectEdge :=
        ((LeftValue <= AOtsuThreshold) <> CenterClass) or
        ((RightValue <= AOtsuThreshold) <> CenterClass) or
        ((TopValue <= AOtsuThreshold) <> CenterClass) or
        ((BottomValue <= AOtsuThreshold) <> CenterClass);

      GradientX := RightValue - LeftValue;
      GradientY := BottomValue - TopValue;

      LaplacianValue :=
        (4 * CenterValue) -
        LeftValue -
        RightValue -
        TopValue -
        BottomValue;

      { Data fallback tetap dihitung untuk kondisi preparat dengan
        sedikit piksel tepi. }
      FallbackSum :=
        FallbackSum +
        Sqr(Double(LaplacianValue));

      Inc(FallbackCount);

      if IsObjectEdge then
      begin
        SumGradientSquare :=
          SumGradientSquare +
          Sqr(Double(GradientX)) +
          Sqr(Double(GradientY));

        SumLaplacianSquare :=
          SumLaplacianSquare +
          Sqr(Double(LaplacianValue));

        Inc(EdgeCount);
      end;

      Inc(X, PixelStep);
    end;

    Inc(Y, PixelStep);
  end;

  { Minimal tepi diperlukan agar skor tidak ditentukan oleh beberapa
    piksel noise saja. }
  if EdgeCount >= 30 then
  begin
    GradientRMS :=
      Sqrt(SumGradientSquare / EdgeCount);

    LaplacianRMS :=
      Sqrt(SumLaplacianSquare / EdgeCount);

    { Gradient merupakan komponen utama ketajaman batas objek.
      Laplacian hanya menjadi penguat detail lokal. Pembagian 10 hanya
      menjaga skala angka mudah dibaca pada tampilan Delphi. }
    Result :=
      (GradientRMS +
       (0.25 * LaplacianRMS)) / 10.0;
  end
  else if FallbackCount > 0 then
  begin
    Result :=
      Sqrt(FallbackSum / FallbackCount) / 10.0;
  end;

  if Result < 0 then
    Result := 0;
end;

procedure TfrmMain.UpdateNilaiOtsuDanFocus(
  const PaintImage: IocvImage
);
var
  RawImage: IocvImage;
  GrayImage: IocvImage;

  SampleMotor: TPendingMotor;
  SamplePosition: Integer;
  AverageFocus: Double;
  AverageOtsu: Double;
begin
  if not FCameraActive then
    Exit;

  Inc(FFrameCounter);

  { Perhitungan setiap tiga frame agar preview tetap ringan. }
  if (FFrameCounter mod 3) <> 0 then
    Exit;

  RawImage := nil;

  if Assigned(ocvCameraSource1) and
     (ocvCameraSource1.Image <> nil) then
  begin
    RawImage := ocvCameraSource1.Image;
  end;

  if RawImage = nil then
    RawImage := PaintImage;

  if RawImage = nil then
    Exit;

  GrayImage := RawImage.GrayImage;

  if GrayImage = nil then
    Exit;

  FLastOtsu :=
    HitungOtsuDariImage(GrayImage);

  FLastFocus :=
    HitungFocusScoreDariImage(
      GrayImage,
      FLastOtsu
    );

  lblCurrentOtsu.Caption :=
    IntToStr(FLastOtsu);

  lblCurrentFocus.Caption :=
    FormatFloat('0.000', FLastFocus);

  lblFocusInfo.Caption :=
    'Otsu edge sharpness';

  if FGraphSamplePending then
  begin
    Inc(FGraphSampleCount);

    FGraphFocusSum :=
      FGraphFocusSum +
      FLastFocus;

    FGraphOtsuSum :=
      FGraphOtsuSum +
      FLastOtsu;

    if FGraphSampleCount = 1 then
    begin
      FGraphFocusMin := FLastFocus;
      FGraphFocusMax := FLastFocus;
      FGraphOtsuMin := FLastOtsu;
      FGraphOtsuMax := FLastOtsu;
    end
    else
    begin
      if FLastFocus < FGraphFocusMin then
        FGraphFocusMin := FLastFocus;

      if FLastFocus > FGraphFocusMax then
        FGraphFocusMax := FLastFocus;

      if FLastOtsu < FGraphOtsuMin then
        FGraphOtsuMin := FLastOtsu;

      if FLastOtsu > FGraphOtsuMax then
        FGraphOtsuMax := FLastOtsu;
    end;

    SetStatus(
      'Mengambil sampel grafik ' +
      IntToStr(FGraphSampleCount) +
      ' dari ' +
      IntToStr(FGraphSampleTargetCount)
    );

    if FGraphSampleCount >= FGraphSampleTargetCount then
    begin
      SampleMotor := FGraphSampleMotor;
      SamplePosition := FGraphSamplePosition;

      { Buang satu nilai tertinggi dan satu terendah. Ini mengurangi
        pengaruh noise atau getaran sesaat pada pemilihan fokus. }
      if FGraphSampleCount > 2 then
      begin
        AverageFocus :=
          (FGraphFocusSum -
           FGraphFocusMin -
           FGraphFocusMax) /
          (FGraphSampleCount - 2);

        AverageOtsu :=
          (FGraphOtsuSum -
           FGraphOtsuMin -
           FGraphOtsuMax) /
          (FGraphSampleCount - 2);
      end
      else
      begin
        AverageFocus :=
          FGraphFocusSum /
          FGraphSampleCount;

        AverageOtsu :=
          FGraphOtsuSum /
          FGraphSampleCount;
      end;

      AddGraphPoint(
        SampleMotor,
        SamplePosition,
        AverageFocus,
        AverageOtsu
      );

      ResetGraphSampling;

      if FAutoFocusRunning and
         (FAutoFocusState = afsSampling) and
         (SampleMotor in [pmMacro, pmMicro]) then
      begin
        HandleAutoFocusSample(
          SampleMotor,
          SamplePosition,
          AverageFocus,
          AverageOtsu
        );
      end
      else
      begin
        UpdateMotorControlState;
      end;
    end;
  end
  else if rbThresholdOtsu.Checked then
  begin
    lblThresholdValue.Caption := 'AUTO';

    SetStatus(
      'Threshold Otsu otomatis: ' +
      IntToStr(FLastOtsu)
    );
  end;
end;

procedure TfrmMain.ocvView1BeforePaint(
  Sender: TObject;
  var IplImage: IocvImage
);
begin
  UpdateNilaiOtsuDanFocus(IplImage);
end;

{ ============================================================================
  PENGAMBILAN DAN PENYIMPANAN DATA GRAFIK
  ============================================================================ }

procedure TfrmMain.ResetGraphSampling;
begin
  FGraphSampleMotor := pmNone;
  FGraphSamplePosition := 0;
  FGraphSamplePending := False;
  FGraphSampleCount := 0;
  FGraphSampleTargetCount := AUTOFOCUS_SAMPLE_COUNT;
  FGraphFocusSum := 0;
  FGraphOtsuSum := 0;
  FGraphFocusMin := 0;
  FGraphFocusMax := 0;
  FGraphOtsuMin := 0;
  FGraphOtsuMax := 0;
end;

procedure TfrmMain.StartGraphSampling(
  AMotor: TPendingMotor;
  APosition: Integer;
  ASampleCount: Integer
);
begin
  if not FCameraActive then
  begin
    ResetGraphSampling;
    UpdateMotorControlState;
    Exit;
  end;

  FGraphSampleMotor := AMotor;
  FGraphSamplePosition := APosition;
  FGraphSamplePending := True;
  FGraphSampleCount := 0;

  if ASampleCount > 0 then
    FGraphSampleTargetCount := ASampleCount
  else
    FGraphSampleTargetCount := AUTOFOCUS_SAMPLE_COUNT;

  FGraphFocusSum := 0;
  FGraphOtsuSum := 0;
  FGraphFocusMin := 0;
  FGraphFocusMax := 0;
  FGraphOtsuMin := 0;
  FGraphOtsuMax := 0;

  UpdateMotorControlState;

  case AMotor of
    pmMacro:
      SetStatus(
        'Makrometer stabil. Mengambil ' +
        IntToStr(FGraphSampleTargetCount) +
        ' sampel pada posisi ' +
        IntToStr(APosition)
      );

    pmMicro:
      SetStatus(
        'Mikrometer stabil. Mengambil ' +
        IntToStr(FGraphSampleTargetCount) +
        ' sampel pada posisi ' +
        IntToStr(APosition)
      );
  end;
end;

procedure TfrmMain.AddGraphPoint(
  AMotor: TPendingMotor;
  APosition: Integer;
  AFocus: Double;
  AOtsu: Double
);
var
  MotorName: string;

  TargetFocusSeries: TLineSeries;
  TargetOtsuSeries: TLineSeries;
  TargetFocusChart: TChart;
  TargetOtsuChart: TChart;

  Positions: array of Double;
  FocusValues: array of Double;
  OtsuValues: array of Double;

  I: Integer;
  J: Integer;
  DataCount: Integer;
  ExistingIndex: Integer;

  TempPosition: Double;
  TempFocus: Double;
  TempOtsu: Double;

  DataUpdated: Boolean;
begin
  if AMotor = pmNone then
    Exit;

  TargetFocusSeries := nil;
  TargetOtsuSeries := nil;
  TargetFocusChart := nil;
  TargetOtsuChart := nil;

  { Setiap motor mempunyai chart dan series sendiri. Data Makrometer
    tidak lagi dihapus ketika pemindaian berpindah ke Mikrometer. }
  case AMotor of
    pmMacro:
      begin
        MotorName := 'Makrometer';

        TargetFocusSeries := serFocus;
        TargetOtsuSeries := serOtsu;
        TargetFocusChart := chtFocus;
        TargetOtsuChart := chtOtsu;
      end;

    pmMicro:
      begin
        MotorName := 'Mikrometer';

        TargetFocusSeries := serFocusMicro;
        TargetOtsuSeries := serOtsuMicro;
        TargetFocusChart := chtFocusMicro;
        TargetOtsuChart := chtOtsuMicro;
      end;
  else
    Exit;
  end;

  if (TargetFocusSeries = nil) or
     (TargetOtsuSeries = nil) or
     (TargetFocusChart = nil) or
     (TargetOtsuChart = nil) then
  begin
    Exit;
  end;

  ExistingIndex := -1;

  for I := 0 to TargetFocusSeries.Count - 1 do
  begin
    if Round(TargetFocusSeries.XValue[I]) = APosition then
    begin
      ExistingIndex := I;
      Break;
    end;
  end;

  DataUpdated := ExistingIndex >= 0;

  if DataUpdated then
    DataCount := TargetFocusSeries.Count
  else
    DataCount := TargetFocusSeries.Count + 1;

  SetLength(Positions, DataCount);
  SetLength(FocusValues, DataCount);
  SetLength(OtsuValues, DataCount);

  for I := 0 to TargetFocusSeries.Count - 1 do
  begin
    Positions[I] := TargetFocusSeries.XValue[I];
    FocusValues[I] := TargetFocusSeries.YValue[I];

    if I < TargetOtsuSeries.Count then
      OtsuValues[I] := TargetOtsuSeries.YValue[I]
    else
      OtsuValues[I] := 0;
  end;

  if DataUpdated then
  begin
    Positions[ExistingIndex] := APosition;
    FocusValues[ExistingIndex] := AFocus;
    OtsuValues[ExistingIndex] := AOtsu;
  end
  else
  begin
    Positions[DataCount - 1] := APosition;
    FocusValues[DataCount - 1] := AFocus;
    OtsuValues[DataCount - 1] := AOtsu;
  end;

  for I := 0 to DataCount - 2 do
  begin
    for J := I + 1 to DataCount - 1 do
    begin
      if Positions[J] < Positions[I] then
      begin
        TempPosition := Positions[I];
        Positions[I] := Positions[J];
        Positions[J] := TempPosition;

        TempFocus := FocusValues[I];
        FocusValues[I] := FocusValues[J];
        FocusValues[J] := TempFocus;

        TempOtsu := OtsuValues[I];
        OtsuValues[I] := OtsuValues[J];
        OtsuValues[J] := TempOtsu;
      end;
    end;
  end;

  TargetFocusSeries.Clear;
  TargetOtsuSeries.Clear;

  for I := 0 to DataCount - 1 do
  begin
    TargetFocusSeries.AddXY(
      Positions[I],
      FocusValues[I]
    );

    TargetOtsuSeries.AddXY(
      Positions[I],
      OtsuValues[I]
    );
  end;

  TargetFocusChart.Repaint;
  TargetOtsuChart.Repaint;

  if DataUpdated then
  begin
    SetStatus(
      'Data grafik ' +
      MotorName +
      ' posisi ' +
      IntToStr(APosition) +
      ' diperbarui | Focus: ' +
      FormatFloat('0.000', AFocus) +
      ' | Otsu: ' +
      FormatFloat('0.0', AOtsu)
    );
  end
  else
  begin
    SetStatus(
      'Data grafik ' +
      MotorName +
      ' posisi ' +
      IntToStr(APosition) +
      ' tersimpan | Focus: ' +
      FormatFloat('0.000', AFocus) +
      ' | Otsu: ' +
      FormatFloat('0.0', AOtsu)
    );
  end;
end;

{ ============================================================================
  INISIALISASI KONTROL MOTOR
  ============================================================================ }

procedure TfrmMain.InitializeMotorControls;
begin
  FPendingMotor := pmNone;

  FMacroPosition := 0;
  FMicroPosition := 0;

  edtMacroTarget.Text := '0';
  edtMicroTarget.Text := '0';

  lblMacroCurrentPosition.Caption := '0 langkah';
  lblMicroCurrentPosition.Caption := '0 langkah';

  lblMacroPositionValue.Caption := 'Makro: 0';
  lblMicroPositionValue.Caption := 'Mikro: 0';

  btnMoveMacro.Enabled := False;
  btnMoveMicro.Enabled := False;

  edtMacroTarget.Enabled := False;
  edtMicroTarget.Enabled := False;
end;

{ ============================================================================
  AUTOFOCUS OTSU-EDGE + VERIFIKASI KANDIDAT - TAHAP 13
  ============================================================================ }

procedure TfrmMain.ResetCandidateList(
  var AList: TFocusCandidateArray;
  var ACount: Integer
);
var
  I: Integer;
begin
  ACount := 0;

  for I := Low(AList) to High(AList) do
  begin
    AList[I].Position := 0;
    AList[I].Score := -1;
  end;
end;

procedure TfrmMain.AddFocusCandidate(
  var AList: TFocusCandidateArray;
  var ACount: Integer;
  APosition: Integer;
  AScore: Double
);
var
  I: Integer;
  J: Integer;
  ExistingIndex: Integer;
  Temp: TFocusCandidate;
begin
  ExistingIndex := -1;

  for I := 0 to ACount - 1 do
  begin
    if AList[I].Position = APosition then
    begin
      ExistingIndex := I;
      Break;
    end;
  end;

  if ExistingIndex >= 0 then
  begin
    AList[ExistingIndex].Score := AScore;
  end
  else if ACount < AUTOFOCUS_CANDIDATE_COUNT then
  begin
    AList[ACount].Position := APosition;
    AList[ACount].Score := AScore;
    Inc(ACount);
  end
  else if AScore > AList[ACount - 1].Score then
  begin
    AList[ACount - 1].Position := APosition;
    AList[ACount - 1].Score := AScore;
  end
  else
    Exit;

  { Urutkan kandidat dari skor tertinggi ke terendah. }
  for I := 0 to ACount - 2 do
  begin
    for J := I + 1 to ACount - 1 do
    begin
      if AList[J].Score > AList[I].Score then
      begin
        Temp := AList[I];
        AList[I] := AList[J];
        AList[J] := Temp;
      end;
    end;
  end;
end;

procedure TfrmMain.UpdateAllControlStates;
begin
  UpdateMotorControlState;
  UpdateCameraControlState;
  UpdateLensControlState;
end;

procedure TfrmMain.UpdateAutoFocusProgress;
var
  PercentValue: Integer;
begin
  if FAutoFocusTotalPoints <= 0 then
    PercentValue := 0
  else
    PercentValue := Round(
      (FAutoFocusPointsDone * 100.0) /
      FAutoFocusTotalPoints
    );

  if PercentValue < 0 then
    PercentValue := 0
  else if PercentValue > 100 then
    PercentValue := 100;

  pbAutoFocus.Position := PercentValue;

  lblScanProgressPercent.Caption :=
    IntToStr(PercentValue) + '%';
end;

function TfrmMain.CalculateSeriesMedian(
  ASeries: TLineSeries
): Double;
var
  Values: array of Double;
  I, J: Integer;
  Temp: Double;
begin
  Result := 0;

  if (ASeries = nil) or
     (ASeries.Count <= 0) then
    Exit;

  SetLength(Values, ASeries.Count);

  for I := 0 to ASeries.Count - 1 do
    Values[I] := ASeries.YValue[I];

  for I := 0 to Length(Values) - 2 do
  begin
    for J := I + 1 to Length(Values) - 1 do
    begin
      if Values[J] < Values[I] then
      begin
        Temp := Values[I];
        Values[I] := Values[J];
        Values[J] := Temp;
      end;
    end;
  end;

  if (Length(Values) mod 2) = 1 then
    Result := Values[Length(Values) div 2]
  else
    Result :=
      (Values[(Length(Values) div 2) - 1] +
       Values[Length(Values) div 2]) / 2.0;
end;

function TfrmMain.CalculateMacroRelativeQuality(
  ASeries: TLineSeries;
  APeakFocus: Double;
  out AMedianFocus: Double
): Double;
const
  MIN_BASELINE = 0.000001;
var
  Baseline: Double;
begin
  AMedianFocus := CalculateSeriesMedian(ASeries);
  Baseline := Abs(AMedianFocus);

  if Baseline < MIN_BASELINE then
    Baseline := MIN_BASELINE;

  Result :=
    (APeakFocus - AMedianFocus) /
    Baseline;

  if Result < 0 then
    Result := 0;
end;

function TfrmMain.CalculatePeakNeighborhoodAverage(
  ASeries: TLineSeries;
  APeakPosition: Integer;
  ARadius: Integer
): Double;
var
  I: Integer;
  SampleCount: Integer;
  TotalValue: Double;
begin
  Result := 0;

  if (ASeries = nil) or
     (ASeries.Count <= 0) then
    Exit;

  if ARadius < 0 then
    ARadius := 0;

  SampleCount := 0;
  TotalValue := 0;

  for I := 0 to ASeries.Count - 1 do
  begin
    if Abs(
      ASeries.XValue[I] -
      APeakPosition
    ) <= ARadius then
    begin
      TotalValue :=
        TotalValue +
        ASeries.YValue[I];

      Inc(SampleCount);
    end;
  end;

  if SampleCount > 0 then
  begin
    Result :=
      TotalValue /
      SampleCount;
  end;
end;

procedure TfrmMain.SaveCompletedMacroOnlyResult(
  ALens: Integer
);
begin
  case ALens of
    1:
      begin
        CopyLineSeriesData(serFocus, serFocusMacro4XResult);
        CopyLineSeriesData(serOtsu, serOtsuMacro4XResult);

        serFocusMicro4XResult.Clear;
        serOtsuMicro4XResult.Clear;
        FBestMicroMarker4X.Clear;
        FBestMicroOtsuMarker4X.Clear;

        FResult4XAvailable := True;
        FResult4XBestMacro := FAutoFocusBestMacroPosition;
        FResult4XBestMacroFocus := FAutoFocusBestMacroFocus;
        FResult4XBestMicro := 0;
        FResult4XBestFocus := FAutoFocusBestMacroFocus;
        FResult4XBestMicroOtsu := 0;

        SetBestPointMarker(
          FBestMacroMarker4X,
          FResult4XBestMacro,
          FResult4XBestMacroFocus
        );

        if TryGetSeriesYAtX(
          serOtsuMacro4XResult,
          FResult4XBestMacro,
          FResult4XBestMacroOtsu
        ) then
        begin
          SetBestPointMarker(
            FBestMacroOtsuMarker4X,
            FResult4XBestMacro,
            FResult4XBestMacroOtsu
          );
        end
        else
          FBestMacroOtsuMarker4X.Clear;

        SetResultChartTitle(
          chtFocusMacro4XResult,
          'Focus Score Makrometer Objektif 4×',
          'Makro terbaik: ' +
          IntToStr(FResult4XBestMacro) +
          ' langkah | Focus Makro: ' +
          FormatFloat('0.000', FResult4XBestMacroFocus)
        );

        SetResultChartTitle(
          chtOtsuMacro4XResult,
          'Nilai Otsu Makrometer Objektif 4×',
          'Makro terbaik: ' +
          IntToStr(FResult4XBestMacro) +
          ' langkah | Otsu: ' +
          FormatFloat('0.0', FResult4XBestMacroOtsu)
        );

        SetResultChartTitle(
          chtFocusMicro4XResult,
          'Focus Score Mikrometer Objektif 4×',
          'Scan Mikro hanya dijalankan apabila Objektif 4× menjadi pemenang.'
        );

        SetResultChartTitle(
          chtOtsuMicro4XResult,
          'Nilai Otsu Mikrometer Objektif 4×',
          'Scan Mikro belum dijalankan.'
        );

        chtFocusMacro4XResult.Repaint;
        chtOtsuMacro4XResult.Repaint;
        chtFocusMicro4XResult.Repaint;
        chtOtsuMicro4XResult.Repaint;
      end;

    2:
      begin
        CopyLineSeriesData(serFocus, serFocusMacro10XResult);
        CopyLineSeriesData(serOtsu, serOtsuMacro10XResult);

        serFocusMicro10XResult.Clear;
        serOtsuMicro10XResult.Clear;
        FBestMicroMarker10X.Clear;
        FBestMicroOtsuMarker10X.Clear;

        FResult10XAvailable := True;
        FResult10XBestMacro := FAutoFocusBestMacroPosition;
        FResult10XBestMacroFocus := FAutoFocusBestMacroFocus;
        FResult10XBestMicro := 0;
        FResult10XBestFocus := FAutoFocusBestMacroFocus;
        FResult10XBestMicroOtsu := 0;

        SetBestPointMarker(
          FBestMacroMarker10X,
          FResult10XBestMacro,
          FResult10XBestMacroFocus
        );

        if TryGetSeriesYAtX(
          serOtsuMacro10XResult,
          FResult10XBestMacro,
          FResult10XBestMacroOtsu
        ) then
        begin
          SetBestPointMarker(
            FBestMacroOtsuMarker10X,
            FResult10XBestMacro,
            FResult10XBestMacroOtsu
          );
        end
        else
          FBestMacroOtsuMarker10X.Clear;

        SetResultChartTitle(
          chtFocusMacro10XResult,
          'Focus Score Makrometer Objektif 10×',
          'Makro terbaik: ' +
          IntToStr(FResult10XBestMacro) +
          ' langkah | Focus Makro: ' +
          FormatFloat('0.000', FResult10XBestMacroFocus)
        );

        SetResultChartTitle(
          chtOtsuMacro10XResult,
          'Nilai Otsu Makrometer Objektif 10×',
          'Makro terbaik: ' +
          IntToStr(FResult10XBestMacro) +
          ' langkah | Otsu: ' +
          FormatFloat('0.0', FResult10XBestMacroOtsu)
        );

        SetResultChartTitle(
          chtFocusMicro10XResult,
          'Focus Score Mikrometer Objektif 10×',
          'Scan Mikro hanya dijalankan apabila Objektif 10× menjadi pemenang.'
        );

        SetResultChartTitle(
          chtOtsuMicro10XResult,
          'Nilai Otsu Mikrometer Objektif 10×',
          'Scan Mikro belum dijalankan.'
        );

        chtFocusMacro10XResult.Repaint;
        chtOtsuMacro10XResult.Repaint;
        chtFocusMicro10XResult.Repaint;
        chtOtsuMicro10XResult.Repaint;
      end;
  end;

  UpdateSaveResultButtonState;
end;

procedure TfrmMain.CancelDualAutoFocus(
  const AReason: string;
  AShowMessage: Boolean
);
begin
  FDualAutoFocusActive := False;
  FDualAutoFocusStopRequested := False;
  FDualAutoFocusStage := dafsIdle;
  FDualWinnerLens := 0;

  FAutoFocusRunning := False;
  FAutoFocusStopRequested := False;
  FAutoFocusRunMode := afrmSingleLens;
  FAutoFocusState := afsIdle;
  FAutoFocusPhase := afpNone;
  FAutoFocusMoveMotor := pmNone;
  FPendingMotor := pmNone;

  if Assigned(FAutoFocusTimer) then
    FAutoFocusTimer.Enabled := False;

  ResetGraphSampling;

  lblScanStageValue.Caption := 'Dihentikan';
  UpdateAllControlStates;
  SetStatus(AReason);

  if AShowMessage then
    ShowMessage(AReason);
end;

procedure TfrmMain.StartDualAutoFocus;
begin
  if FDualAutoFocusActive or
     FAutoFocusRunning then
    Exit;

  if not SystemConnectionConnected then
  begin
    ShowMessage('Hubungkan ESP32 A melalui WiFi atau COM terlebih dahulu.');
    Exit;
  end;

  if not LensCommandChannelAvailable then
  begin
    ShowMessage('Jalur komunikasi revolver belum tersedia.');
    Exit;
  end;

  if not FCameraActive then
  begin
    ShowMessage('Aktifkan kamera terlebih dahulu.');
    Exit;
  end;

  if not FLensInitialPositionConfirmed or
     not (FLensActive in [1, 2]) then
  begin
    ShowMessage(
      'Posisi objektif belum diketahui. Hubungkan dan konfirmasi ' +
      'ESP32 A terlebih dahulu.'
    );
    Exit;
  end;

  if not FZProfileSynchronized then
  begin
    ShowMessage('Profil ESP32 sumbu Z belum sinkron dengan objektif aktif.');
    Exit;
  end;

  if (FLensChangeState <> lcsIdle) or
     FLensMoving or
     (FPendingMotor <> pmNone) or
     FGraphSamplePending then
  begin
    ShowMessage('Tunggu sampai seluruh gerakan sebelumnya selesai.');
    Exit;
  end;

  FDualAutoFocusActive := True;
  FDualAutoFocusStopRequested := False;
  FDualAutoFocusStage := dafsPreparing4X;
  FDualWinnerLens := 0;

  FDual4XBestMacroPosition := 0;
  FDual4XBestMacroFocus := -1;
  FDual4XMacroMedian := 0;
  FDual4XMacroQuality := 0;

  FDual10XBestMacroPosition := 0;
  FDual10XBestMacroFocus := -1;
  FDual10XMacroMedian := 0;
  FDual10XMacroQuality := 0;

  lblBestMacroValue.Caption := '-';
  lblBestMicroValue.Caption := '-';
  lblBestFocusValue.Caption := '-';
  lblScanStageValue.Caption := 'Menyiapkan Objektif 4×';
  lblScanProgressPercent.Caption := '0%';
  pbAutoFocus.Position := 0;

  pcRightControl.ActivePage := tabAutoFocusControl;
  pcMainView.ActivePage := tabGraph;

  UpdateAllControlStates;

  SetStatus(
    'Autofokus otomatis dimulai: Makro 4×, Makro 10×, ' +
    'lalu Mikro pada objektif pemenang.'
  );

  if FLensActive = 1 then
    ContinueDualAutoFocusAfterLensReady
  else
    RequestLensChange(1, True);
end;

procedure TfrmMain.ContinueDualAutoFocusAfterLensReady;
begin
  if not FDualAutoFocusActive then
    Exit;

  if FDualAutoFocusStopRequested then
  begin
    CancelDualAutoFocus('Autofokus otomatis dihentikan oleh pengguna.');
    Exit;
  end;

  if not FZProfileSynchronized or
     (FLensChangeState <> lcsIdle) or
     FLensMoving then
    Exit;

  case FDualAutoFocusStage of
    dafsPreparing4X:
      begin
        if FLensActive <> 1 then
        begin
          CancelDualAutoFocus(
            'Objektif 4× gagal disiapkan.',
            True
          );
          Exit;
        end;

        FDualAutoFocusStage := dafsScanningMacro4X;
        lblScanStageValue.Caption := 'Scan Makro Objektif 4×';
        StartMacroOnlyAutoFocus;
      end;

    dafsPreparing10X:
      begin
        if FLensActive <> 2 then
        begin
          CancelDualAutoFocus(
            'Objektif 10× gagal disiapkan.',
            True
          );
          Exit;
        end;

        FDualAutoFocusStage := dafsScanningMacro10X;
        lblScanStageValue.Caption := 'Scan Makro Objektif 10×';
        StartMacroOnlyAutoFocus;
      end;

    dafsPreparingWinner:
      begin
        if FLensActive <> FDualWinnerLens then
        begin
          CancelDualAutoFocus(
            'Objektif pemenang gagal disiapkan.',
            True
          );
          Exit;
        end;

        FDualAutoFocusStage := dafsScanningWinnerMicro;

        case FDualWinnerLens of
          1:
            begin
              CopyLineSeriesData(
                serFocusMacro4XResult,
                serFocus
              );
              CopyLineSeriesData(
                serOtsuMacro4XResult,
                serOtsu
              );

              StartMicroOnlyAutoFocus(
                FDual4XBestMacroPosition,
                FDual4XBestMacroFocus
              );
            end;

          2:
            begin
              CopyLineSeriesData(
                serFocusMacro10XResult,
                serFocus
              );
              CopyLineSeriesData(
                serOtsuMacro10XResult,
                serOtsu
              );

              StartMicroOnlyAutoFocus(
                FDual10XBestMacroPosition,
                FDual10XBestMacroFocus
              );
            end;
        else
          CancelDualAutoFocus(
            'Objektif pemenang tidak valid.',
            True
          );
        end;
      end;
  end;
end;

procedure TfrmMain.StartMacroOnlyAutoFocus;
var
  MacroPointCount: Integer;
begin
  if not FDualAutoFocusActive then
    Exit;

  FAutoFocusRunMode := afrmMacroOnly;
  FAutoFocusMacroEnd := ActiveMacroMaximum;
  ApplyActiveMacroRange;

  MacroPointCount :=
    ((FAutoFocusMacroEnd - AUTOFOCUS_MACRO_START) div
      AUTOFOCUS_MACRO_STEP) + 1;

  FAutoFocusRunning := True;
  FAutoFocusStopRequested := False;
  FAutoFocusState := afsIdle;
  FAutoFocusPhase := afpNone;
  FAutoFocusMoveMotor := pmNone;
  FAutoFocusCurrentTarget := 0;

  FAutoFocusBestMacroPosition := AUTOFOCUS_MACRO_START;
  FAutoFocusBestMacroFocus := -1;
  FAutoFocusBestMicroPosition := 0;
  FAutoFocusBestMicroFocus := -1;

  ResetCandidateList(FMacroCandidates, FMacroCandidateCount);
  ResetCandidateList(FMicroCandidates, FMicroCandidateCount);

  FVerifyCandidateIndex := 0;
  FVerifyBestPosition := 0;
  FVerifyBestFocus := -1;

  FAutoFocusPointsDone := 0;
  FAutoFocusTotalPoints :=
    MacroPointCount + AUTOFOCUS_CANDIDATE_COUNT;

  ResetGraphSampling;
  FGraphActiveMotor := pmNone;
  ClearAllGraphSeries;

  lblScanProgressPercent.Caption := '0%';
  pbAutoFocus.Position := 0;
  lblBestMacroValue.Caption := '-';
  lblBestMicroValue.Caption := '-';
  lblBestFocusValue.Caption := '-';

  UpdateAllControlStates;

  if FMicroPosition <> 0 then
  begin
    FAutoFocusPhase := afpPrepareMicroCenter;
    QueueAutoFocusMove(pmMicro, 0, False);
  end
  else
    StartMacroScan;
end;

procedure TfrmMain.CompleteMacroOnlyAutoFocus;
var
  LensName: string;
begin
  if Assigned(FAutoFocusTimer) then
    FAutoFocusTimer.Enabled := False;

  FAutoFocusRunning := False;
  FAutoFocusStopRequested := False;
  FAutoFocusState := afsIdle;
  FAutoFocusPhase := afpNone;
  FAutoFocusMoveMotor := pmNone;
  FPendingMotor := pmNone;
  ResetGraphSampling;

  case FLensActive of
    1:
      begin
        LensName := '4×';
        FDual4XBestMacroPosition := FAutoFocusBestMacroPosition;
        FDual4XBestMacroFocus := FAutoFocusBestMacroFocus;
        FDual4XMacroQuality := CalculateMacroRelativeQuality(
          serFocus,
          FDual4XBestMacroFocus,
          FDual4XMacroMedian
        );
      end;

    2:
      begin
        LensName := '10×';
        FDual10XBestMacroPosition := FAutoFocusBestMacroPosition;
        FDual10XBestMacroFocus := FAutoFocusBestMacroFocus;
        FDual10XMacroQuality := CalculateMacroRelativeQuality(
          serFocus,
          FDual10XBestMacroFocus,
          FDual10XMacroMedian
        );
      end;
  else
    CancelDualAutoFocus(
      'Objektif aktif tidak diketahui setelah scan Makro.',
      True
    );
    Exit;
  end;

  SaveCompletedMacroOnlyResult(FLensActive);

  lblBestMacroValue.Caption :=
    IntToStr(FAutoFocusBestMacroPosition);
  lblBestMicroValue.Caption := '-';
  lblBestFocusValue.Caption :=
    FormatFloat('0.000', FAutoFocusBestMacroFocus);

  SetStatus(
    'Scan Makro Objektif ' + LensName +
    ' selesai | Posisi terbaik: ' +
    IntToStr(FAutoFocusBestMacroPosition) +
    ' | Focus: ' +
    FormatFloat('0.000', FAutoFocusBestMacroFocus)
  );

  UpdateAllControlStates;
  ContinueDualAutoFocusAfterMacroScan;
end;

procedure TfrmMain.ContinueDualAutoFocusAfterMacroScan;
begin
  if not FDualAutoFocusActive then
    Exit;

  if FDualAutoFocusStopRequested then
  begin
    CancelDualAutoFocus('Autofokus otomatis dihentikan oleh pengguna.');
    Exit;
  end;

  case FDualAutoFocusStage of
    dafsScanningMacro4X:
      begin
        FDualAutoFocusStage := dafsPreparing10X;
        lblScanStageValue.Caption := 'Menyiapkan Objektif 10×';
        RequestLensChange(2, True);
      end;

    dafsScanningMacro10X:
      begin
        FDualAutoFocusStage := dafsSelectingWinner;
        SelectDualAutoFocusWinner;
      end;
  else
    CancelDualAutoFocus(
      'Tahap Autofokus otomatis tidak sesuai setelah scan Makro.',
      True
    );
  end;
end;

procedure TfrmMain.SelectDualAutoFocusWinner;
const
  { Radius 100 langkah berarti nilai di sekitar puncak diperiksa
    pada rentang posisi terbaik -100 sampai posisi terbaik +100. }
  PEAK_NEIGHBORHOOD_RADIUS = 100;

  { Focus Score 4× dan 10× tidak selalu berada pada skala yang sama.
    Karena 10× memberikan detail lebih tinggi, 10× tetap dipilih selama
    kualitas relatifnya minimal 60 persen dari kualitas relatif 4×.
    Nilai ini dapat dikalibrasi lagi setelah beberapa pengujian preparat. }
  MIN_10X_QUALITY_RATIO = 0.60;

  { Pemeriksaan tambahan menggunakan rata-rata sekitar puncak.
    Bila rata-rata lokal 10× minimal 70 persen dari 4×, 10× juga
    dianggap masih layak dipilih. }
  MIN_10X_LOCAL_RATIO = 0.70;

  MIN_VALID_SCORE = 0.000001;
var
  WinnerName: string;
  WinnerMacro: Integer;

  LocalAverage4X: Double;
  LocalAverage10X: Double;
  QualityRatio10To4: Double;
  LocalRatio10To4: Double;
  Valid4X: Boolean;
  Valid10X: Boolean;
begin
  if not FDualAutoFocusActive then
    Exit;

  LocalAverage4X :=
    CalculatePeakNeighborhoodAverage(
      serFocusMacro4XResult,
      FDual4XBestMacroPosition,
      PEAK_NEIGHBORHOOD_RADIUS
    );

  LocalAverage10X :=
    CalculatePeakNeighborhoodAverage(
      serFocusMacro10XResult,
      FDual10XBestMacroPosition,
      PEAK_NEIGHBORHOOD_RADIUS
    );

  Valid4X :=
    (FDual4XBestMacroFocus > MIN_VALID_SCORE) and
    (FDual4XMacroQuality > MIN_VALID_SCORE) and
    (LocalAverage4X > MIN_VALID_SCORE);

  Valid10X :=
    (FDual10XBestMacroFocus > MIN_VALID_SCORE) and
    (FDual10XMacroQuality > MIN_VALID_SCORE) and
    (LocalAverage10X > MIN_VALID_SCORE);

  if not Valid4X and not Valid10X then
  begin
    CancelDualAutoFocus(
      'Data fokus Makro Objektif 4× dan 10× tidak valid.',
      True
    );
    Exit;
  end;

  QualityRatio10To4 := 0;
  LocalRatio10To4 := 0;

  if Valid4X then
  begin
    QualityRatio10To4 :=
      FDual10XMacroQuality /
      FDual4XMacroQuality;

    LocalRatio10To4 :=
      LocalAverage10X /
      LocalAverage4X;
  end;

  { Urutan keputusan:
    1. Bila hanya satu objektif mempunyai data valid, pilih objektif itu.
    2. Bila keduanya valid, prioritaskan 10× apabila kualitasnya masih
       minimal 60% dari 4× atau rata-rata lokalnya minimal 70% dari 4×.
    3. Pilih 4× hanya ketika hasil 10× memang jauh lebih buruk. }
  if Valid10X and not Valid4X then
  begin
    FDualWinnerLens := 2;
  end
  else if Valid4X and not Valid10X then
  begin
    FDualWinnerLens := 1;
  end
  else if
    (QualityRatio10To4 >= MIN_10X_QUALITY_RATIO) or
    (LocalRatio10To4 >= MIN_10X_LOCAL_RATIO) then
  begin
    FDualWinnerLens := 2;
  end
  else
  begin
    FDualWinnerLens := 1;
  end;

  case FDualWinnerLens of
    1:
      begin
        WinnerName := '4×';
        WinnerMacro := FDual4XBestMacroPosition;
      end;

    2:
      begin
        WinnerName := '10×';
        WinnerMacro := FDual10XBestMacroPosition;
      end;
  else
    CancelDualAutoFocus(
      'Pemenang objektif tidak valid.',
      True
    );
    Exit;
  end;

  lblScanStageValue.Caption :=
    'Pemenang Makro: Objektif ' + WinnerName;

  SetStatus(
    'Perbandingan Makro selesai' +
    ' | Kualitas relatif 4×: ' +
    FormatFloat('0.000', FDual4XMacroQuality) +
    ' | Kualitas relatif 10×: ' +
    FormatFloat('0.000', FDual10XMacroQuality) +
    ' | Rata-rata puncak 4×: ' +
    FormatFloat('0.000', LocalAverage4X) +
    ' | Rata-rata puncak 10×: ' +
    FormatFloat('0.000', LocalAverage10X) +
    ' | Rasio kualitas 10×/4×: ' +
    FormatFloat('0.000', QualityRatio10To4) +
    ' | Pemenang: Objektif ' + WinnerName +
    ' | Makro terbaik: ' + IntToStr(WinnerMacro)
  );

  FDualAutoFocusStage := dafsPreparingWinner;

  if FLensActive = FDualWinnerLens then
    ContinueDualAutoFocusAfterLensReady
  else
    RequestLensChange(FDualWinnerLens, True);
end;

procedure TfrmMain.StartMicroOnlyAutoFocus(
  ABestMacroPosition: Integer;
  ABestMacroFocus: Double
);
var
  MicroCoarsePointCount: Integer;
  MicroFineMaxPointCount: Integer;
begin
  if not FDualAutoFocusActive then
    Exit;

  FAutoFocusRunMode := afrmMicroOnly;
  FAutoFocusMacroEnd := ActiveMacroMaximum;
  ApplyActiveMacroRange;

  MicroCoarsePointCount :=
    ((AUTOFOCUS_MICRO_END - AUTOFOCUS_MICRO_START) div
      AUTOFOCUS_MICRO_COARSE_STEP) + 1;

  MicroFineMaxPointCount :=
    ((AUTOFOCUS_MICRO_FINE_HALF_RANGE * 2) div
      AUTOFOCUS_MICRO_FINE_STEP) + 1;

  FAutoFocusRunning := True;
  FAutoFocusStopRequested := False;
  FAutoFocusState := afsIdle;
  FAutoFocusPhase := afpPrepareWinnerMacro;
  FAutoFocusMoveMotor := pmNone;
  FAutoFocusCurrentTarget := 0;

  FAutoFocusBestMacroPosition := ABestMacroPosition;
  FAutoFocusBestMacroFocus := ABestMacroFocus;

  FAutoFocusBestMicroPosition := 0;
  FAutoFocusBestMicroFocus := -1;
  FAutoFocusBestMicroCoarsePosition := 0;
  FAutoFocusBestMicroCoarseFocus := -1;
  FAutoFocusMicroFineStart := 0;
  FAutoFocusMicroFineEnd := 0;

  ResetCandidateList(FMicroCandidates, FMicroCandidateCount);
  FVerifyCandidateIndex := 0;
  FVerifyBestPosition := 0;
  FVerifyBestFocus := -1;

  FAutoFocusPointsDone := 0;
  FAutoFocusTotalPoints :=
    MicroCoarsePointCount +
    MicroFineMaxPointCount +
    AUTOFOCUS_CANDIDATE_COUNT;

  ResetGraphSampling;
  FGraphActiveMotor := pmNone;

  serFocusMicro.Clear;
  serOtsuMicro.Clear;

  lblScanProgressPercent.Caption := '0%';
  pbAutoFocus.Position := 0;
  lblScanStageValue.Caption := 'Makro menuju posisi pemenang';

  lblBestMacroValue.Caption :=
    IntToStr(ABestMacroPosition);
  lblBestMicroValue.Caption := '-';
  lblBestFocusValue.Caption :=
    FormatFloat('0.000', ABestMacroFocus);

  pcGraphView.ActivePage := tabFocusMicroGraph;
  UpdateAllControlStates;

  QueueAutoFocusMove(
    pmMacro,
    ABestMacroPosition,
    False
  );
end;

procedure TfrmMain.FinishDualAutoFocus;
var
  WinnerName: string;
begin
  case FDualWinnerLens of
    1: WinnerName := '4×';
    2: WinnerName := '10×';
  else
    WinnerName := '?';
  end;

  FDualAutoFocusStage := dafsCompleted;
  FDualAutoFocusActive := False;
  FDualAutoFocusStopRequested := False;
  FAutoFocusRunMode := afrmSingleLens;

  lblScanStageValue.Caption :=
    'Selesai - Objektif terbaik ' + WinnerName;

  UpdateAllControlStates;

  SetStatus(
    'Autofokus otomatis selesai | Objektif terbaik: ' +
    WinnerName +
    ' | Kualitas Makro 4×: ' +
    FormatFloat('0.000', FDual4XMacroQuality) +
    ' | Kualitas Makro 10×: ' +
    FormatFloat('0.000', FDual10XMacroQuality) +
    ' | Makro akhir: ' +
    IntToStr(FAutoFocusBestMacroPosition) +
    ' | Mikro akhir: ' +
    IntToStr(FAutoFocusBestMicroPosition) +
    ' | Focus akhir: ' +
    FormatFloat('0.000', FAutoFocusBestMicroFocus)
  );
end;

procedure TfrmMain.StartFullAutoFocus;
var
  MacroPointCount: Integer;
  MicroCoarsePointCount: Integer;
  MicroFineMaxPointCount: Integer;
begin
  if FAutoFocusRunning then
    Exit;

  if FDualAutoFocusActive then
  begin
    ShowMessage(
      'Autofokus otomatis dua objektif masih berlangsung.'
    );
    Exit;
  end;

  FAutoFocusRunMode := afrmSingleLens;

  if (FLensChangeState <> lcsIdle) or
     FLensMoving then
  begin
    ShowMessage(
      'Tunggu sampai perpindahan objektif selesai.'
    );
    Exit;
  end;

  if not SystemConnectionConnected then
  begin
    ShowMessage('Hubungkan ESP32 A melalui WiFi atau COM terlebih dahulu.');
    Exit;
  end;

  if FLensInitialPositionConfirmed and
     (not FZProfileSynchronized) then
  begin
    ShowMessage('Profil objektif ESP32 sumbu Z belum sinkron.');
    Exit;
  end;

  if not FCameraActive then
  begin
    ShowMessage('Aktifkan kamera terlebih dahulu.');
    Exit;
  end;

  if (FPendingMotor <> pmNone) or
     FGraphSamplePending then
  begin
    ShowMessage(
      'Tunggu sampai gerakan atau pengambilan sampel selesai.'
    );
    Exit;
  end;

  FAutoFocusMacroEnd := ActiveMacroMaximum;

  if (FAutoFocusMacroEnd < AUTOFOCUS_MACRO_START) or
     (FAutoFocusMacroEnd > MACRO_MAX_POS) then
  begin
    ShowMessage('Batas Makrometer profil aktif tidak valid.');
    Exit;
  end;

  ApplyActiveMacroRange;

  MacroPointCount :=
    ((FAutoFocusMacroEnd -
      AUTOFOCUS_MACRO_START) div
      AUTOFOCUS_MACRO_STEP) + 1;

  MicroCoarsePointCount :=
    ((AUTOFOCUS_MICRO_END -
      AUTOFOCUS_MICRO_START) div
      AUTOFOCUS_MICRO_COARSE_STEP) + 1;

  MicroFineMaxPointCount :=
    ((AUTOFOCUS_MICRO_FINE_HALF_RANGE * 2) div
      AUTOFOCUS_MICRO_FINE_STEP) + 1;

  FAutoFocusRunning := True;
  FAutoFocusStopRequested := False;
  FAutoFocusState := afsIdle;
  FAutoFocusPhase := afpNone;
  FAutoFocusMoveMotor := pmNone;
  FAutoFocusCurrentTarget := 0;

  FAutoFocusBestMacroPosition :=
    AUTOFOCUS_MACRO_START;

  FAutoFocusBestMacroFocus := -1;

  FAutoFocusBestMicroPosition := 0;
  FAutoFocusBestMicroFocus := -1;

  FAutoFocusBestMicroCoarsePosition := 0;
  FAutoFocusBestMicroCoarseFocus := -1;

  FAutoFocusMicroFineStart := 0;
  FAutoFocusMicroFineEnd := 0;

  ResetCandidateList(
    FMacroCandidates,
    FMacroCandidateCount
  );

  ResetCandidateList(
    FMicroCandidates,
    FMicroCandidateCount
  );

  FVerifyCandidateIndex := 0;
  FVerifyBestPosition := 0;
  FVerifyBestFocus := -1;

  FAutoFocusPointsDone := 0;

  FAutoFocusTotalPoints :=
    MacroPointCount +
    AUTOFOCUS_CANDIDATE_COUNT +
    MicroCoarsePointCount +
    MicroFineMaxPointCount +
    AUTOFOCUS_CANDIDATE_COUNT;

  ResetGraphSampling;
  FGraphActiveMotor := pmNone;
  ClearAllGraphSeries;

  lblScanStageValue.Caption :=
    'Persiapan sistem';

  lblScanProgressPercent.Caption := '0%';
  pbAutoFocus.Position := 0;

  lblBestMacroValue.Caption := '-';
  lblBestMicroValue.Caption := '-';
  lblBestFocusValue.Caption := '-';

  pcRightControl.ActivePage :=
    tabAutoFocusControl;

  pcMainView.ActivePage := tabGraph;
  pcGraphView.ActivePage := tabFocusGraph;

  UpdateAllControlStates;

  { Mikrometer dibuat netral agar scan Makrometer dimulai
    dari kondisi fine adjustment yang konsisten. }
  if FMicroPosition <> 0 then
  begin
    FAutoFocusPhase :=
      afpPrepareMicroCenter;

    lblScanStageValue.Caption :=
      'Mikrometer ke posisi 0';

    SetStatus(
      'Persiapan Autofokus: Mikrometer dikembalikan ke posisi 0.'
    );

    QueueAutoFocusMove(
      pmMicro,
      0,
      False
    );
  end
  else
    StartMacroScan;
end;

procedure TfrmMain.StartMacroScan;
begin
  if not FAutoFocusRunning then
    Exit;

  FAutoFocusPhase := afpMacroScan;
  FAutoFocusBestMacroPosition := AUTOFOCUS_MACRO_START;
  FAutoFocusBestMacroFocus := -1;

  ResetCandidateList(
    FMacroCandidates,
    FMacroCandidateCount
  );

  FGraphActiveMotor := pmMacro;
  serFocus.Clear;
  serOtsu.Clear;

  pcGraphView.ActivePage := tabFocusGraph;

  lblScanStageValue.Caption := 'Mulai scan Makrometer';

  SetStatus(
    'Tahap kasar: Makrometer dipindai dari 0 sampai ' +
    IntToStr(FAutoFocusMacroEnd) +
    ' dengan interval ' +
    IntToStr(AUTOFOCUS_MACRO_STEP) +
    ' langkah.'
  );

  QueueAutoFocusMove(
    pmMacro,
    AUTOFOCUS_MACRO_START,
    False
  );
end;

procedure TfrmMain.StartMacroVerification;
begin
  if not FAutoFocusRunning then
    Exit;

  if FMacroCandidateCount <= 0 then
  begin
    AbortAutoFocus(
      'Verifikasi Makrometer gagal karena tidak ada kandidat fokus.'
    );
    Exit;
  end;

  FAutoFocusPhase := afpMacroVerify;
  FVerifyCandidateIndex := 0;
  FVerifyBestPosition := FMacroCandidates[0].Position;
  FVerifyBestFocus := -1;

  FAutoFocusBestMacroFocus := -1;

  lblScanStageValue.Caption :=
    'Verifikasi kandidat Makro';

  SetStatus(
    'Memverifikasi ' +
    IntToStr(FMacroCandidateCount) +
    ' kandidat Makrometer menggunakan ' +
    IntToStr(AUTOFOCUS_VERIFY_SAMPLE_COUNT) +
    ' frame per kandidat.'
  );

  QueueAutoFocusMove(
    pmMacro,
    FMacroCandidates[0].Position,
    False
  );
end;

procedure TfrmMain.StartMicroCoarseScan;
begin
  if not FAutoFocusRunning then
    Exit;

  FAutoFocusPhase := afpMicroCoarseScan;

  FAutoFocusBestMicroCoarsePosition :=
    AUTOFOCUS_MICRO_START;

  FAutoFocusBestMicroCoarseFocus := -1;

  FAutoFocusBestMicroPosition :=
    AUTOFOCUS_MICRO_START;

  FAutoFocusBestMicroFocus := -1;

  FGraphActiveMotor := pmMicro;

  if Assigned(serFocusMicro) then
    serFocusMicro.Clear;

  if Assigned(serOtsuMicro) then
    serOtsuMicro.Clear;

  if Assigned(tabFocusMicroGraph) then
    pcGraphView.ActivePage := tabFocusMicroGraph;

  lblScanStageValue.Caption :=
    'Mulai scan Mikro kasar';

  SetStatus(
    'Mikrometer scan kasar dari -1600 sampai 1600 ' +
    'dengan interval 100 pulse.'
  );

  QueueAutoFocusMove(
    pmMicro,
    AUTOFOCUS_MICRO_START,
    False
  );
end;

procedure TfrmMain.StartMicroFineScan;
var
  FinePointCount: Integer;
begin
  if not FAutoFocusRunning then
    Exit;

  if FAutoFocusBestMicroCoarseFocus < 0 then
  begin
    AbortAutoFocus(
      'Scan Mikro halus tidak dapat dimulai karena data kasar kosong.'
    );
    Exit;
  end;

  FAutoFocusMicroFineStart :=
    FAutoFocusBestMicroCoarsePosition -
    AUTOFOCUS_MICRO_FINE_HALF_RANGE;

  FAutoFocusMicroFineEnd :=
    FAutoFocusBestMicroCoarsePosition +
    AUTOFOCUS_MICRO_FINE_HALF_RANGE;

  if FAutoFocusMicroFineStart <
     AUTOFOCUS_MICRO_START then
  begin
    FAutoFocusMicroFineStart :=
      AUTOFOCUS_MICRO_START;
  end;

  if FAutoFocusMicroFineEnd >
     AUTOFOCUS_MICRO_END then
  begin
    FAutoFocusMicroFineEnd :=
      AUTOFOCUS_MICRO_END;
  end;

  FinePointCount :=
    ((FAutoFocusMicroFineEnd -
      FAutoFocusMicroFineStart) div
      AUTOFOCUS_MICRO_FINE_STEP) + 1;

  { Sisa progress disesuaikan dengan rentang halus aktual. }
  FAutoFocusTotalPoints :=
    FAutoFocusPointsDone +
    FinePointCount +
    AUTOFOCUS_CANDIDATE_COUNT;

  UpdateAutoFocusProgress;

  FAutoFocusPhase := afpMicroFineScan;

  FAutoFocusBestMicroPosition :=
    FAutoFocusBestMicroCoarsePosition;

  FAutoFocusBestMicroFocus := -1;

  ResetCandidateList(
    FMicroCandidates,
    FMicroCandidateCount
  );

  lblBestMicroValue.Caption :=
    IntToStr(
      FAutoFocusBestMicroCoarsePosition
    );

  FGraphActiveMotor := pmMicro;

  { Data scan kasar Mikrometer dipertahankan. Titik scan halus
    akan ditambahkan atau memperbarui posisi yang sama. }
  if Assigned(tabFocusMicroGraph) then
    pcGraphView.ActivePage := tabFocusMicroGraph;

  lblScanStageValue.Caption :=
    'Mulai scan Mikro halus';

  SetStatus(
    'Mikrometer scan halus dari ' +
    IntToStr(FAutoFocusMicroFineStart) +
    ' sampai ' +
    IntToStr(FAutoFocusMicroFineEnd) +
    ' dengan interval 1 langkah.'
  );

  QueueAutoFocusMove(
    pmMicro,
    FAutoFocusMicroFineStart,
    False
  );
end;

procedure TfrmMain.StartMicroVerification;
begin
  if not FAutoFocusRunning then
    Exit;

  if FMicroCandidateCount <= 0 then
  begin
    AbortAutoFocus(
      'Verifikasi Mikrometer gagal karena tidak ada kandidat fokus.'
    );
    Exit;
  end;

  FAutoFocusPhase := afpMicroVerify;
  FVerifyCandidateIndex := 0;
  FVerifyBestPosition := FMicroCandidates[0].Position;
  FVerifyBestFocus := -1;

  FAutoFocusBestMicroFocus := -1;

  lblScanStageValue.Caption :=
    'Verifikasi kandidat Mikro';

  SetStatus(
    'Memverifikasi ' +
    IntToStr(FMicroCandidateCount) +
    ' kandidat Mikrometer menggunakan ' +
    IntToStr(AUTOFOCUS_VERIFY_SAMPLE_COUNT) +
    ' frame per kandidat.'
  );

  QueueAutoFocusMove(
    pmMicro,
    FMicroCandidates[0].Position,
    False
  );
end;

procedure TfrmMain.QueueAutoFocusMove(
  AMotor: TPendingMotor;
  ATarget: Integer;
  AReturning: Boolean
);
begin
  if not FAutoFocusRunning then
    Exit;

  case AMotor of
    pmMacro:
      begin
        if ATarget < AUTOFOCUS_MACRO_START then
          ATarget := AUTOFOCUS_MACRO_START
        else if ATarget > FAutoFocusMacroEnd then
          ATarget := FAutoFocusMacroEnd;
      end;

    pmMicro:
      begin
        if ATarget < AUTOFOCUS_MICRO_START then
          ATarget := AUTOFOCUS_MICRO_START
        else if ATarget > AUTOFOCUS_MICRO_END then
          ATarget := AUTOFOCUS_MICRO_END;
      end;
  else
    AbortAutoFocus('Motor Autofokus tidak valid.');
    Exit;
  end;

  FAutoFocusMoveMotor := AMotor;
  FAutoFocusCurrentTarget := ATarget;

  if AReturning then
    FAutoFocusState := afsReadyReturn
  else
    FAutoFocusState := afsReadyMove;

  case AMotor of
    pmMacro:
      lblScanStageValue.Caption :=
        'Makro menuju ' + IntToStr(ATarget);

    pmMicro:
      lblScanStageValue.Caption :=
        'Mikro menuju ' + IntToStr(ATarget);
  end;

  if Assigned(FAutoFocusTimer) then
  begin
    FAutoFocusTimer.Enabled := False;
    FAutoFocusTimer.Interval :=
      AUTOFOCUS_COMMAND_DELAY_MS;
    FAutoFocusTimer.Enabled := True;
  end;
end;

procedure TfrmMain.BeginSettledSampling(
  AMotor: TPendingMotor
);
begin
  if not FAutoFocusRunning then
    Exit;

  FAutoFocusMoveMotor := AMotor;
  FAutoFocusState := afsSettling;

  case AMotor of
    pmMacro:
      lblScanStageValue.Caption :=
        'Stabilisasi Makro ' +
        IntToStr(FMacroPosition);

    pmMicro:
      lblScanStageValue.Caption :=
        'Stabilisasi Mikro ' +
        IntToStr(FMicroPosition);
  end;

  SetStatus(
    'Menunggu getaran motor reda selama ' +
    IntToStr(AUTOFOCUS_SETTLE_DELAY_MS) +
    ' ms.'
  );

  if Assigned(FAutoFocusTimer) then
  begin
    FAutoFocusTimer.Enabled := False;
    if FAutoFocusPhase in [
      afpMacroVerify,
      afpMicroVerify
    ] then
    begin
      FAutoFocusTimer.Interval :=
        AUTOFOCUS_VERIFY_SETTLE_DELAY_MS;
    end
    else
    begin
      FAutoFocusTimer.Interval :=
        AUTOFOCUS_SETTLE_DELAY_MS;
    end;
    FAutoFocusTimer.Enabled := True;
  end;
end;

procedure TfrmMain.QueueReturnMacroBest;
begin
  if not FAutoFocusRunning then
    Exit;

  FAutoFocusPhase := afpMacroReturn;

  lblScanStageValue.Caption :=
    'Makro kembali ke terbaik';

  SetStatus(
    'Makrometer kembali ke posisi terbaik ' +
    IntToStr(FAutoFocusBestMacroPosition) + '.'
  );

  QueueAutoFocusMove(
    pmMacro,
    FAutoFocusBestMacroPosition,
    True
  );
end;

procedure TfrmMain.QueueReturnMicroBest;
var
  ApproachPosition: Integer;
begin
  if not FAutoFocusRunning then
    Exit;

  { Scan bergerak dari nilai kecil ke besar. Posisi akhir juga harus
    didekati dari arah yang sama agar celah gear tidak menggeser fokus. }
  ApproachPosition :=
    FAutoFocusBestMicroPosition -
    AUTOFOCUS_MICRO_BACKLASH_STEPS;

  if ApproachPosition < AUTOFOCUS_MICRO_START then
    ApproachPosition := AUTOFOCUS_MICRO_START;

  if ApproachPosition <
     FAutoFocusBestMicroPosition then
  begin
    FAutoFocusPhase :=
      afpMicroBacklashPrep;

    lblScanStageValue.Caption :=
      'Kompensasi backlash Mikro';

    SetStatus(
      'Mikrometer bergerak ke ' +
      IntToStr(ApproachPosition) +
      ', kemudian maju ke posisi terbaik ' +
      IntToStr(FAutoFocusBestMicroPosition) +
      '.'
    );

    QueueAutoFocusMove(
      pmMicro,
      ApproachPosition,
      True
    );
  end
  else
  begin
    FAutoFocusPhase := afpMicroReturn;

    QueueAutoFocusMove(
      pmMicro,
      FAutoFocusBestMicroPosition,
      True
    );
  end;
end;

procedure TfrmMain.AutoFocusTimerTick(Sender: TObject);
var
  CommandSent: Boolean;
begin
  if Assigned(FAutoFocusTimer) then
    FAutoFocusTimer.Enabled := False;

  if not FAutoFocusRunning then
    Exit;

  if FAutoFocusStopRequested then
  begin
    CancelAutoFocus(
      'Autofokus dihentikan oleh pengguna.'
    );
    Exit;
  end;

  { Setelah motor berhenti, tunggu stabil sebelum mengambil citra. }
  if FAutoFocusState = afsSettling then
  begin
    FAutoFocusState := afsSampling;

    case FAutoFocusMoveMotor of
      pmMacro:
        begin
          lblScanStageValue.Caption :=
            'Mengukur Makro ' +
            IntToStr(FMacroPosition);

          if FAutoFocusPhase = afpMacroVerify then
          begin
            StartGraphSampling(
              pmMacro,
              FMacroPosition,
              AUTOFOCUS_VERIFY_SAMPLE_COUNT
            );
          end
          else
          begin
            StartGraphSampling(
              pmMacro,
              FMacroPosition,
              AUTOFOCUS_SAMPLE_COUNT
            );
          end;
        end;

      pmMicro:
        begin
          lblScanStageValue.Caption :=
            'Mengukur Mikro ' +
            IntToStr(FMicroPosition);

          if FAutoFocusPhase = afpMicroVerify then
          begin
            StartGraphSampling(
              pmMicro,
              FMicroPosition,
              AUTOFOCUS_VERIFY_SAMPLE_COUNT
            );
          end
          else
          begin
            StartGraphSampling(
              pmMicro,
              FMicroPosition,
              AUTOFOCUS_SAMPLE_COUNT
            );
          end;
        end;
    else
      AbortAutoFocus(
        'Motor sampling Autofokus tidak valid.'
      );
    end;

    Exit;
  end;

  if not (FAutoFocusState in [
    afsReadyMove,
    afsReadyReturn
  ]) then
    Exit;

  if FAutoFocusState = afsReadyMove then
  begin
    FAutoFocusState := afsMoving;
  end
  else
  begin
    { Target yang sama tidak perlu dikirim ulang. }
    case FAutoFocusMoveMotor of
      pmMacro:
        if FMacroPosition =
           FAutoFocusCurrentTarget then
        begin
          if FAutoFocusPhase = afpMacroReturn then
          begin
            if FAutoFocusRunMode = afrmMacroOnly then
              CompleteMacroOnlyAutoFocus
            else
              StartMicroCoarseScan;
          end
          else
            AbortAutoFocus(
              'Fase kembali Makrometer tidak sesuai.'
            );

          Exit;
        end;

      pmMicro:
        if FMicroPosition =
           FAutoFocusCurrentTarget then
        begin
          case FAutoFocusPhase of
            afpMicroBacklashPrep:
              begin
                FAutoFocusPhase :=
                  afpMicroReturn;

                QueueAutoFocusMove(
                  pmMicro,
                  FAutoFocusBestMicroPosition,
                  True
                );
              end;

            afpMicroReturn:
              CompleteFullAutoFocus;
          else
            AbortAutoFocus(
              'Fase kembali Mikrometer tidak sesuai.'
            );
          end;

          Exit;
        end;
    end;

    FAutoFocusState := afsReturning;
  end;

  FPendingMotor := FAutoFocusMoveMotor;
  UpdateAllControlStates;

  case FAutoFocusMoveMotor of
    pmMacro:
      begin
        SetStatus(
          'Autofokus: Makrometer bergerak ke posisi ' +
          IntToStr(FAutoFocusCurrentTarget)
        );

        CommandSent :=
          SendMacroTarget(
            FAutoFocusCurrentTarget
          );
      end;

    pmMicro:
      begin
        SetStatus(
          'Autofokus: Mikrometer bergerak ke posisi ' +
          IntToStr(FAutoFocusCurrentTarget)
        );

        CommandSent :=
          SendMicroTarget(
            FAutoFocusCurrentTarget
          );
      end;
  else
    CommandSent := False;
  end;

  if not CommandSent then
  begin
    FPendingMotor := pmNone;

    AbortAutoFocus(
      'Gagal mengirim target Autofokus ke ESP32.'
    );
  end;
end;

procedure TfrmMain.HandleAutoFocusMotorDone(
  AMotor: TPendingMotor
);
begin
  if not FAutoFocusRunning then
    Exit;

  if FAutoFocusStopRequested then
  begin
    CancelAutoFocus(
      'Autofokus dihentikan setelah gerakan motor selesai.'
    );
    Exit;
  end;

  case FAutoFocusState of
    afsMoving:
      begin
        case FAutoFocusPhase of
          afpPrepareMicroCenter:
            begin
              if AMotor <> pmMicro then
              begin
                AbortAutoFocus(
                  'Motor tidak sesuai saat persiapan Mikrometer.'
                );
                Exit;
              end;

              if FAutoFocusRunMode = afrmMicroOnly then
                StartMicroCoarseScan
              else
                StartMacroScan;
            end;

          afpPrepareWinnerMacro:
            begin
              if AMotor <> pmMacro then
              begin
                AbortAutoFocus(
                  'Motor tidak sesuai saat menuju Makro pemenang.'
                );
                Exit;
              end;

              if FMicroPosition <> 0 then
              begin
                FAutoFocusPhase := afpPrepareMicroCenter;
                QueueAutoFocusMove(pmMicro, 0, False);
              end
              else
                StartMicroCoarseScan;
            end;

          afpMacroScan,
          afpMacroVerify:
            begin
              if AMotor <> pmMacro then
              begin
                AbortAutoFocus(
                  'Motor tidak sesuai pada scan/verifikasi Makrometer.'
                );
                Exit;
              end;

              BeginSettledSampling(pmMacro);
            end;

          afpMicroCoarseScan,
          afpMicroFineScan,
          afpMicroVerify:
            begin
              if AMotor <> pmMicro then
              begin
                AbortAutoFocus(
                  'Motor tidak sesuai pada scan Mikrometer.'
                );
                Exit;
              end;

              BeginSettledSampling(pmMicro);
            end;
        else
          AbortAutoFocus(
            'Tahap Autofokus tidak sesuai saat gerakan selesai.'
          );
        end;
      end;

    afsReturning:
      begin
        case FAutoFocusPhase of
          afpMacroReturn:
            begin
              if AMotor <> pmMacro then
              begin
                AbortAutoFocus(
                  'Motor tidak sesuai saat kembali ke Makro terbaik.'
                );
                Exit;
              end;

              if FAutoFocusRunMode = afrmMacroOnly then
                CompleteMacroOnlyAutoFocus
              else
                StartMicroCoarseScan;
            end;

          afpMicroBacklashPrep:
            begin
              if AMotor <> pmMicro then
              begin
                AbortAutoFocus(
                  'Motor tidak sesuai saat kompensasi backlash.'
                );
                Exit;
              end;

              FAutoFocusPhase :=
                afpMicroReturn;

              lblScanStageValue.Caption :=
                'Mikro menuju terbaik';

              QueueAutoFocusMove(
                pmMicro,
                FAutoFocusBestMicroPosition,
                True
              );
            end;

          afpMicroReturn:
            begin
              if AMotor <> pmMicro then
              begin
                AbortAutoFocus(
                  'Motor tidak sesuai saat kembali ke Mikro terbaik.'
                );
                Exit;
              end;

              CompleteFullAutoFocus;
            end;
        else
          AbortAutoFocus(
            'Tahap kembali Autofokus tidak sesuai.'
          );
        end;
      end;

    afsReadyReturn:
      begin
        SetStatus(
          'Batas mekanik selesai diproses. ' +
          'Menunggu gerakan kembali ke posisi terbaik.'
        );
      end;
  else
    AbortAutoFocus(
      'State Autofokus tidak sesuai saat motor selesai.'
    );
  end;
end;

procedure TfrmMain.HandleAutoFocusSample(
  AMotor: TPendingMotor;
  APosition: Integer;
  AFocus: Double;
  AOtsu: Double
);
begin
  if not FAutoFocusRunning then
    Exit;

  Inc(FAutoFocusPointsDone);

  case AMotor of
    pmMacro:
      begin
        case FAutoFocusPhase of
          afpMacroScan:
            begin
              AddFocusCandidate(
                FMacroCandidates,
                FMacroCandidateCount,
                APosition,
                AFocus
              );

              if (FAutoFocusBestMacroFocus < 0) or
                 (AFocus > FAutoFocusBestMacroFocus) then
              begin
                FAutoFocusBestMacroFocus := AFocus;
                FAutoFocusBestMacroPosition := APosition;

                lblBestMacroValue.Caption :=
                  IntToStr(APosition);

                lblBestFocusValue.Caption :=
                  FormatFloat('0.000', AFocus);
              end;

              UpdateAutoFocusProgress;

              SetStatus(
                'Scan Makro ' +
                IntToStr(APosition) +
                ' | Edge Focus: ' +
                FormatFloat('0.000', AFocus) +
                ' | Kandidat utama: ' +
                IntToStr(FMacroCandidates[0].Position)
              );

              if FAutoFocusCurrentTarget >=
                 FAutoFocusMacroEnd then
              begin
                StartMacroVerification;
              end
              else
              begin
                QueueAutoFocusMove(
                  pmMacro,
                  FAutoFocusCurrentTarget +
                  AUTOFOCUS_MACRO_STEP,
                  False
                );
              end;
            end;

          afpMacroVerify:
            begin
              if (FVerifyBestFocus < 0) or
                 (AFocus > FVerifyBestFocus) then
              begin
                FVerifyBestFocus := AFocus;
                FVerifyBestPosition := APosition;
              end;

              lblBestMacroValue.Caption :=
                IntToStr(FVerifyBestPosition);

              lblBestFocusValue.Caption :=
                FormatFloat('0.000', FVerifyBestFocus);

              UpdateAutoFocusProgress;

              SetStatus(
                'Verifikasi Makro ' +
                IntToStr(APosition) +
                ' | Edge Focus: ' +
                FormatFloat('0.000', AFocus) +
                ' | Terbaik: ' +
                IntToStr(FVerifyBestPosition)
              );

              Inc(FVerifyCandidateIndex);

              if FVerifyCandidateIndex <
                 FMacroCandidateCount then
              begin
                QueueAutoFocusMove(
                  pmMacro,
                  FMacroCandidates[
                    FVerifyCandidateIndex
                  ].Position,
                  False
                );
              end
              else
              begin
                FAutoFocusBestMacroPosition :=
                  FVerifyBestPosition;

                FAutoFocusBestMacroFocus :=
                  FVerifyBestFocus;

                QueueReturnMacroBest;
              end;
            end;
        else
          begin
            AbortAutoFocus(
              'Fase sampel Makrometer tidak sesuai.'
            );
            Exit;
          end;
        end;
      end;

    pmMicro:
      begin
        case FAutoFocusPhase of
          afpMicroCoarseScan:
            begin
              if (FAutoFocusBestMicroCoarseFocus < 0) or
                 (AFocus > FAutoFocusBestMicroCoarseFocus) then
              begin
                FAutoFocusBestMicroCoarseFocus := AFocus;
                FAutoFocusBestMicroCoarsePosition := APosition;

                lblBestMicroValue.Caption :=
                  IntToStr(APosition);

                lblBestFocusValue.Caption :=
                  FormatFloat('0.000', AFocus);
              end;

              UpdateAutoFocusProgress;

              SetStatus(
                'Scan Mikro kasar ' +
                IntToStr(APosition) +
                ' | Edge Focus: ' +
                FormatFloat('0.000', AFocus) +
                ' | Terbaik: ' +
                IntToStr(
                  FAutoFocusBestMicroCoarsePosition
                )
              );

              if FAutoFocusCurrentTarget >=
                 AUTOFOCUS_MICRO_END then
              begin
                StartMicroFineScan;
              end
              else
              begin
                QueueAutoFocusMove(
                  pmMicro,
                  FAutoFocusCurrentTarget +
                  AUTOFOCUS_MICRO_COARSE_STEP,
                  False
                );
              end;
            end;

          afpMicroFineScan:
            begin
              AddFocusCandidate(
                FMicroCandidates,
                FMicroCandidateCount,
                APosition,
                AFocus
              );

              if (FAutoFocusBestMicroFocus < 0) or
                 (AFocus > FAutoFocusBestMicroFocus) then
              begin
                FAutoFocusBestMicroFocus := AFocus;
                FAutoFocusBestMicroPosition := APosition;

                lblBestMicroValue.Caption :=
                  IntToStr(APosition);

                lblBestFocusValue.Caption :=
                  FormatFloat('0.000', AFocus);
              end;

              UpdateAutoFocusProgress;

              SetStatus(
                'Scan Mikro halus ' +
                IntToStr(APosition) +
                ' | Edge Focus: ' +
                FormatFloat('0.000', AFocus) +
                ' | Kandidat utama: ' +
                IntToStr(FMicroCandidates[0].Position)
              );

              if FAutoFocusCurrentTarget >=
                 FAutoFocusMicroFineEnd then
              begin
                StartMicroVerification;
              end
              else
              begin
                QueueAutoFocusMove(
                  pmMicro,
                  FAutoFocusCurrentTarget +
                  AUTOFOCUS_MICRO_FINE_STEP,
                  False
                );
              end;
            end;

          afpMicroVerify:
            begin
              if (FVerifyBestFocus < 0) or
                 (AFocus > FVerifyBestFocus) then
              begin
                FVerifyBestFocus := AFocus;
                FVerifyBestPosition := APosition;
              end;

              lblBestMicroValue.Caption :=
                IntToStr(FVerifyBestPosition);

              lblBestFocusValue.Caption :=
                FormatFloat('0.000', FVerifyBestFocus);

              UpdateAutoFocusProgress;

              SetStatus(
                'Verifikasi Mikro ' +
                IntToStr(APosition) +
                ' | Edge Focus: ' +
                FormatFloat('0.000', AFocus) +
                ' | Terbaik: ' +
                IntToStr(FVerifyBestPosition)
              );

              Inc(FVerifyCandidateIndex);

              if FVerifyCandidateIndex <
                 FMicroCandidateCount then
              begin
                QueueAutoFocusMove(
                  pmMicro,
                  FMicroCandidates[
                    FVerifyCandidateIndex
                  ].Position,
                  False
                );
              end
              else
              begin
                FAutoFocusBestMicroPosition :=
                  FVerifyBestPosition;

                FAutoFocusBestMicroFocus :=
                  FVerifyBestFocus;

                QueueReturnMicroBest;
              end;
            end;
        else
          begin
            AbortAutoFocus(
              'Fase sampel Mikrometer tidak sesuai.'
            );
            Exit;
          end;
        end;
      end;
  else
    begin
      AbortAutoFocus(
        'Motor sampel Autofokus tidak valid.'
      );
      Exit;
    end;
  end;
end;

procedure TfrmMain.CompleteFullAutoFocus;
var
  SavedGraphText: string;
  WasDualAutoFocus: Boolean;
begin
  WasDualAutoFocus :=
    FDualAutoFocusActive and
    (FAutoFocusRunMode = afrmMicroOnly);
  if Assigned(FAutoFocusTimer) then
    FAutoFocusTimer.Enabled := False;

  if FAutoFocusBestMicroFocus < 0 then
  begin
    FAutoFocusBestMicroPosition :=
      FAutoFocusBestMicroCoarsePosition;

    FAutoFocusBestMicroFocus :=
      FAutoFocusBestMicroCoarseFocus;
  end;

  FAutoFocusRunning := False;
  FAutoFocusStopRequested := False;
  FAutoFocusState := afsIdle;
  FAutoFocusPhase := afpNone;
  FAutoFocusMoveMotor := pmNone;
  FPendingMotor := pmNone;

  ResetGraphSampling;

  pbAutoFocus.Position := 100;
  lblScanProgressPercent.Caption := '100%';
  lblScanStageValue.Caption := 'Selesai';

  lblBestMacroValue.Caption :=
    IntToStr(
      FAutoFocusBestMacroPosition
    );

  lblBestMicroValue.Caption :=
    IntToStr(
      FAutoFocusBestMicroPosition
    );

  lblBestFocusValue.Caption :=
    FormatFloat(
      '0.000',
      FAutoFocusBestMicroFocus
    );

  edtMacroTarget.Text :=
    IntToStr(FAutoFocusBestMacroPosition);

  edtMicroTarget.Text :=
    IntToStr(FAutoFocusBestMicroPosition);

  case FLensActive of
    1:
      SavedGraphText :=
        ' | Grafik hasil Objektif 4× disimpan';

    2:
      SavedGraphText :=
        ' | Grafik hasil Objektif 10× disimpan';
  else
    SavedGraphText :=
      ' | Grafik tidak disimpan: objektif tidak diketahui';
  end;

  SaveCompletedAutoFocusResult;

  if WasDualAutoFocus then
  begin
    FinishDualAutoFocus;
    Exit;
  end;

  FAutoFocusRunMode := afrmSingleLens;
  UpdateAllControlStates;

  SetStatus(
    'Autofokus Otsu-edge selesai. Makro terbaik: ' +
    IntToStr(FAutoFocusBestMacroPosition) +
    ' | Mikro terbaik: ' +
    IntToStr(FAutoFocusBestMicroPosition) +
    ' | Focus akhir: ' +
    FormatFloat(
      '0.000',
      FAutoFocusBestMicroFocus
    ) +
    SavedGraphText +
    ' | Titik terbaik ditandai pada grafik Focus dan Otsu'
  );
end;

procedure TfrmMain.CancelAutoFocus(
  const AReason: string
);
begin
  if Assigned(FAutoFocusTimer) then
    FAutoFocusTimer.Enabled := False;

  FAutoFocusRunning := False;
  FAutoFocusStopRequested := False;
  FAutoFocusState := afsIdle;
  FAutoFocusPhase := afpNone;
  FAutoFocusMoveMotor := pmNone;
  FPendingMotor := pmNone;

  ResetGraphSampling;

  if FDualAutoFocusActive then
  begin
    FDualAutoFocusActive := False;
    FDualAutoFocusStopRequested := False;
    FDualAutoFocusStage := dafsIdle;
    FDualWinnerLens := 0;
  end;

  FAutoFocusRunMode := afrmSingleLens;
  lblScanStageValue.Caption := 'Dihentikan';

  UpdateAllControlStates;
  SetStatus(AReason);
end;

procedure TfrmMain.AbortAutoFocus(
  const AReason: string
);
begin
  if Assigned(FAutoFocusTimer) then
    FAutoFocusTimer.Enabled := False;

  FAutoFocusRunning := False;
  FAutoFocusStopRequested := False;
  FAutoFocusState := afsIdle;
  FAutoFocusPhase := afpNone;
  FAutoFocusMoveMotor := pmNone;
  FPendingMotor := pmNone;

  ResetGraphSampling;

  if FDualAutoFocusActive then
  begin
    FDualAutoFocusActive := False;
    FDualAutoFocusStopRequested := False;
    FDualAutoFocusStage := dafsIdle;
    FDualWinnerLens := 0;
  end;

  FAutoFocusRunMode := afrmSingleLens;
  lblScanStageValue.Caption := 'Gagal';

  UpdateAllControlStates;
  SetStatus(AReason);
  ShowMessage(AReason);
end;

procedure TfrmMain.btnStartAutoFocusClick(Sender: TObject);
begin
  StartFullAutoFocus;
end;

procedure TfrmMain.btnStartDualAutoFocusClick(Sender: TObject);
begin
  StartDualAutoFocus;
end;

procedure TfrmMain.btnStopAutoFocusClick(Sender: TObject);
begin
  if not FAutoFocusRunning and
     not FDualAutoFocusActive then
    Exit;

  if FDualAutoFocusActive then
    FDualAutoFocusStopRequested := True;

  FAutoFocusStopRequested := FAutoFocusRunning;
  btnStopAutoFocus.Enabled := False;
  lblScanStageValue.Caption := 'Menghentikan...';

  if FAutoFocusRunning then
  begin
    if FAutoFocusState in [
      afsReadyMove,
      afsSettling,
      afsSampling,
      afsReadyReturn
    ] then
      CancelAutoFocus('Autofokus dihentikan oleh pengguna.')
    else
      SetStatus(
        'Permintaan berhenti diterima. ' +
        'Menunggu gerakan motor selesai.'
      );

    Exit;
  end;

  if FLensMoving then
  begin
    FLensStopRequested := True;
    SendLensCommand('STOP');
    SetStatus(
      'Permintaan berhenti dikirim ke motor revolver.'
    );
    Exit;
  end;

  if FPendingMotor <> pmNone then
  begin
    SetStatus(
      'Permintaan berhenti diterima. ' +
      'Menunggu gerakan pengamanan Z selesai.'
    );
    Exit;
  end;

  CancelDualAutoFocus(
    'Autofokus otomatis dihentikan oleh pengguna.'
  );
end;

{ ============================================================================
  INISIALISASI AUTOFOCUS
  ============================================================================ }

procedure TfrmMain.InitializeAutoFocusControls;
var
  MacroPointCount: Integer;
  MicroCoarsePointCount: Integer;
  MicroFineMaxPointCount: Integer;
begin
  FAutoFocusState := afsIdle;
  FAutoFocusPhase := afpNone;
  FAutoFocusRunMode := afrmSingleLens;

  FDualAutoFocusActive := False;
  FDualAutoFocusStopRequested := False;
  FDualAutoFocusStage := dafsIdle;
  FDualWinnerLens := 0;

  FDual4XBestMacroPosition := 0;
  FDual4XBestMacroFocus := -1;
  FDual4XMacroMedian := 0;
  FDual4XMacroQuality := 0;

  FDual10XBestMacroPosition := 0;
  FDual10XBestMacroFocus := -1;
  FDual10XMacroMedian := 0;
  FDual10XMacroQuality := 0;
  FAutoFocusMoveMotor := pmNone;
  FAutoFocusRunning := False;
  FAutoFocusStopRequested := False;
  FAutoFocusCurrentTarget := 0;
  FAutoFocusMacroEnd := MACRO_MAX_4X;

  FAutoFocusBestMacroPosition :=
    AUTOFOCUS_MACRO_START;

  FAutoFocusBestMacroFocus := -1;

  FAutoFocusBestMicroPosition := 0;
  FAutoFocusBestMicroFocus := -1;

  FAutoFocusBestMicroCoarsePosition := 0;
  FAutoFocusBestMicroCoarseFocus := -1;

  FAutoFocusMicroFineStart := 0;
  FAutoFocusMicroFineEnd := 0;

  ResetCandidateList(
    FMacroCandidates,
    FMacroCandidateCount
  );

  ResetCandidateList(
    FMicroCandidates,
    FMicroCandidateCount
  );

  FVerifyCandidateIndex := 0;
  FVerifyBestPosition := 0;
  FVerifyBestFocus := -1;

  MacroPointCount :=
    ((FAutoFocusMacroEnd -
      AUTOFOCUS_MACRO_START) div
      AUTOFOCUS_MACRO_STEP) + 1;

  MicroCoarsePointCount :=
    ((AUTOFOCUS_MICRO_END -
      AUTOFOCUS_MICRO_START) div
      AUTOFOCUS_MICRO_COARSE_STEP) + 1;

  MicroFineMaxPointCount :=
    ((AUTOFOCUS_MICRO_FINE_HALF_RANGE * 2) div
      AUTOFOCUS_MICRO_FINE_STEP) + 1;

  FAutoFocusPointsDone := 0;

  FAutoFocusTotalPoints :=
    MacroPointCount +
    AUTOFOCUS_CANDIDATE_COUNT +
    MicroCoarsePointCount +
    MicroFineMaxPointCount +
    AUTOFOCUS_CANDIDATE_COUNT;

  btnStartAutoFocus.Enabled := False;
  btnStartDualAutoFocus.Enabled := False;
  btnStopAutoFocus.Enabled := False;

  lblScanStageValue.Caption := 'Menunggu';
  lblScanProgressPercent.Caption := '0%';

  pbAutoFocus.Min := 0;
  pbAutoFocus.Max := 100;
  pbAutoFocus.Position := 0;

  { Caption ringkas agar panel Hasil Pemindaian tetap rapi. }
  lblBestMacroTitle.Caption := 'Makro Terbaik';
  lblBestMicroTitle.Caption := 'Mikro Terbaik';
  lblBestFocusTitle.Caption := 'Focus Terbaik';

  lblBestMacroValue.Caption := '-';
  lblBestMicroValue.Caption := '-';
  lblBestFocusValue.Caption := '-';
end;

{ ============================================================================
  INISIALISASI GRAFIK
  ============================================================================ }

procedure TfrmMain.ClearAllGraphSeries;
begin
  serFocus.Clear;
  serOtsu.Clear;

  if Assigned(serFocusMicro) then
    serFocusMicro.Clear;

  if Assigned(serOtsuMicro) then
    serOtsuMicro.Clear;
end;

procedure TfrmMain.ConfigureLensResultChart(
  AChart: TChart;
  ASeries: TLineSeries;
  const ATitle: string;
  const AXTitle: string;
  const AYTitle: string;
  AXMinimum: Double;
  AXMaximum: Double;
  AXIncrement: Double
);
begin
  if (AChart = nil) or
     (ASeries = nil) then
  begin
    Exit;
  end;

  AChart.Align := alClient;
  AChart.View3D := False;
  AChart.Legend.Visible := False;

  AChart.Title.Text.Clear;
  AChart.Title.Text.Add(ATitle);
  AChart.Title.Font.Size := 10;
  AChart.Title.Font.Style := [fsBold];

  AChart.BottomAxis.Title.Caption :=
    AXTitle;

  AChart.LeftAxis.Title.Caption :=
    AYTitle;

  AChart.BottomAxis.Title.Font.Style :=
    [fsBold];

  AChart.LeftAxis.Title.Font.Style :=
    [fsBold];

  AChart.BottomAxis.LabelsFont.Size := 9;
  AChart.LeftAxis.LabelsFont.Size := 9;

  AChart.BottomAxis.Grid.Visible := True;
  AChart.LeftAxis.Grid.Visible := True;

  AChart.BottomAxis.Grid.Style := psDot;
  AChart.LeftAxis.Grid.Style := psDot;

  AChart.BottomAxis.AxisValuesFormat :=
    '#,##0';

  if SameText(AYTitle, 'Nilai Otsu') then
    AChart.LeftAxis.AxisValuesFormat := '0'
  else
    AChart.LeftAxis.AxisValuesFormat := '0.0##';

  AChart.BottomAxis.Automatic := False;
  AChart.BottomAxis.Minimum := AXMinimum;
  AChart.BottomAxis.Maximum := AXMaximum;
  AChart.BottomAxis.Increment := AXIncrement;

  AChart.LeftAxis.Automatic := True;
  AChart.LeftAxis.Increment := 0;

  ASeries.LinePen.Width := 2;
  ASeries.Pointer.Visible := True;
  ASeries.Pointer.HorizSize := 3;
  ASeries.Pointer.VertSize := 3;
  ASeries.Marks.Visible := False;
end;

procedure TfrmMain.ConfigureBestPointMarker(
  AChart: TChart;
  var AMarker: TPointSeries
);
begin
  if AChart = nil then
    Exit;

  if AMarker = nil then
  begin
    AMarker := TPointSeries.Create(Self);
    AMarker.ParentChart := AChart;
  end;

  AMarker.Title := 'Titik Fokus Terbaik';
  AMarker.SeriesColor := clRed;

  AMarker.Pointer.Style := psCircle;
  AMarker.Pointer.HorizSize := 7;
  AMarker.Pointer.VertSize := 7;
  AMarker.Pointer.Brush.Color := clRed;
  AMarker.Pointer.Pen.Color := clMaroon;

  AMarker.Marks.Visible := False;
  AMarker.ShowInLegend := False;
  AMarker.Clear;
end;

procedure TfrmMain.SetBestPointMarker(
  AMarker: TPointSeries;
  AXValue: Double;
  AYValue: Double
);
begin
  if AMarker = nil then
    Exit;

  AMarker.Clear;
  AMarker.AddXY(
    AXValue,
    AYValue
  );
end;

function TfrmMain.TryGetSeriesYAtX(
  ASeries: TLineSeries;
  AXValue: Double;
  out AYValue: Double
): Boolean;
var
  I: Integer;
  BestIndex: Integer;
  BestDistance: Double;
  CurrentDistance: Double;
begin
  Result := False;
  AYValue := 0;

  if (ASeries = nil) or
     (ASeries.Count = 0) then
  begin
    Exit;
  end;

  BestIndex := 0;
  BestDistance :=
    Abs(
      ASeries.XValue[0] -
      AXValue
    );

  for I := 1 to ASeries.Count - 1 do
  begin
    CurrentDistance :=
      Abs(
        ASeries.XValue[I] -
        AXValue
      );

    if CurrentDistance < BestDistance then
    begin
      BestDistance := CurrentDistance;
      BestIndex := I;
    end;
  end;

  AYValue :=
    ASeries.YValue[BestIndex];

  Result := True;
end;

procedure TfrmMain.SetResultChartTitle(
  AChart: TChart;
  const ABaseTitle: string;
  const ASummary: string
);
begin
  if AChart = nil then
    Exit;

  AChart.Title.Text.Clear;
  AChart.Title.Text.Add(ABaseTitle);

  if Trim(ASummary) <> '' then
    AChart.Title.Text.Add(ASummary);
end;

procedure TfrmMain.UpdateLensResultSummary(
  ALens: Integer
);
var
  GeneralSummary: string;
begin
  case ALens of
    1:
      begin
        if not FResult4XAvailable then
          Exit;

        GeneralSummary :=
          'Makro terbaik: ' +
          IntToStr(FResult4XBestMacro) +
          ' | Mikro terbaik: ' +
          IntToStr(FResult4XBestMicro) +
          ' | Focus akhir: ' +
          FormatFloat(
            '0.000',
            FResult4XBestFocus
          );

        SetResultChartTitle(
          chtFocusMacro4XResult,
          'Focus Score Makrometer Objektif 4×',
          'Titik terbaik: ' +
          IntToStr(FResult4XBestMacro) +
          ' langkah | Focus Makro: ' +
          FormatFloat(
            '0.000',
            FResult4XBestMacroFocus
          )
        );

        SetResultChartTitle(
          chtOtsuMacro4XResult,
          'Nilai Otsu Makrometer Objektif 4×',
          'Makro terbaik: ' +
          IntToStr(FResult4XBestMacro) +
          ' langkah | Otsu pada titik fokus: ' +
          FormatFloat(
            '0.0',
            FResult4XBestMacroOtsu
          )
        );

        SetResultChartTitle(
          chtFocusMicro4XResult,
          'Focus Score Mikrometer Objektif 4×',
          'Titik terbaik: ' +
          IntToStr(FResult4XBestMicro) +
          ' langkah | Focus akhir: ' +
          FormatFloat(
            '0.000',
            FResult4XBestFocus
          )
        );

        SetResultChartTitle(
          chtOtsuMicro4XResult,
          'Nilai Otsu Mikrometer Objektif 4×',
          'Mikro terbaik: ' +
          IntToStr(FResult4XBestMicro) +
          ' langkah | Otsu pada titik fokus: ' +
          FormatFloat(
            '0.0',
            FResult4XBestMicroOtsu
          )
        );
      end;

    2:
      begin
        if not FResult10XAvailable then
          Exit;

        GeneralSummary :=
          'Makro terbaik: ' +
          IntToStr(FResult10XBestMacro) +
          ' | Mikro terbaik: ' +
          IntToStr(FResult10XBestMicro) +
          ' | Focus akhir: ' +
          FormatFloat(
            '0.000',
            FResult10XBestFocus
          );

        SetResultChartTitle(
          chtFocusMacro10XResult,
          'Focus Score Makrometer Objektif 10×',
          'Titik terbaik: ' +
          IntToStr(FResult10XBestMacro) +
          ' langkah | Focus Makro: ' +
          FormatFloat(
            '0.000',
            FResult10XBestMacroFocus
          )
        );

        SetResultChartTitle(
          chtOtsuMacro10XResult,
          'Nilai Otsu Makrometer Objektif 10×',
          'Makro terbaik: ' +
          IntToStr(FResult10XBestMacro) +
          ' langkah | Otsu pada titik fokus: ' +
          FormatFloat(
            '0.0',
            FResult10XBestMacroOtsu
          )
        );

        SetResultChartTitle(
          chtFocusMicro10XResult,
          'Focus Score Mikrometer Objektif 10×',
          'Titik terbaik: ' +
          IntToStr(FResult10XBestMicro) +
          ' langkah | Focus akhir: ' +
          FormatFloat(
            '0.000',
            FResult10XBestFocus
          )
        );

        SetResultChartTitle(
          chtOtsuMicro10XResult,
          'Nilai Otsu Mikrometer Objektif 10×',
          'Mikro terbaik: ' +
          IntToStr(FResult10XBestMicro) +
          ' langkah | Otsu pada titik fokus: ' +
          FormatFloat(
            '0.0',
            FResult10XBestMicroOtsu
          )
        );
      end;
  end;
end;

procedure TfrmMain.InitializeLensResultCharts;
begin
  tabLensResult4X.Caption :=
    'Hasil Objektif 4×';

  tabLensResult10X.Caption :=
    'Hasil Objektif 10×';

  tabFocusMacro4XResult.Caption :=
    'Focus Makro';

  tabOtsuMacro4XResult.Caption :=
    'Otsu Makro';

  tabFocusMicro4XResult.Caption :=
    'Focus Mikro';

  tabOtsuMicro4XResult.Caption :=
    'Otsu Mikro';

  tabFocusMacro10XResult.Caption :=
    'Focus Makro';

  tabOtsuMacro10XResult.Caption :=
    'Otsu Makro';

  tabFocusMicro10XResult.Caption :=
    'Focus Mikro';

  tabOtsuMicro10XResult.Caption :=
    'Otsu Mikro';

  ConfigureLensResultChart(
    chtFocusMacro4XResult,
    serFocusMacro4XResult,
    'Focus Score Makrometer Objektif 4×',
    'Posisi Makrometer (langkah)',
    'Focus Score',
    MACRO_MIN_POS,
    MACRO_MAX_4X,
    500
  );

  ConfigureLensResultChart(
    chtOtsuMacro4XResult,
    serOtsuMacro4XResult,
    'Nilai Otsu Makrometer Objektif 4×',
    'Posisi Makrometer (langkah)',
    'Nilai Otsu',
    MACRO_MIN_POS,
    MACRO_MAX_4X,
    500
  );

  ConfigureLensResultChart(
    chtFocusMicro4XResult,
    serFocusMicro4XResult,
    'Focus Score Mikrometer Objektif 4×',
    'Posisi Mikrometer (langkah)',
    'Focus Score',
    MICRO_MIN_POS,
    MICRO_MAX_POS,
    500
  );

  ConfigureLensResultChart(
    chtOtsuMicro4XResult,
    serOtsuMicro4XResult,
    'Nilai Otsu Mikrometer Objektif 4×',
    'Posisi Mikrometer (langkah)',
    'Nilai Otsu',
    MICRO_MIN_POS,
    MICRO_MAX_POS,
    500
  );

  ConfigureLensResultChart(
    chtFocusMacro10XResult,
    serFocusMacro10XResult,
    'Focus Score Makrometer Objektif 10×',
    'Posisi Makrometer (langkah)',
    'Focus Score',
    MACRO_MIN_POS,
    MACRO_MAX_10X,
    500
  );

  ConfigureLensResultChart(
    chtOtsuMacro10XResult,
    serOtsuMacro10XResult,
    'Nilai Otsu Makrometer Objektif 10×',
    'Posisi Makrometer (langkah)',
    'Nilai Otsu',
    MACRO_MIN_POS,
    MACRO_MAX_10X,
    500
  );

  ConfigureLensResultChart(
    chtFocusMicro10XResult,
    serFocusMicro10XResult,
    'Focus Score Mikrometer Objektif 10×',
    'Posisi Mikrometer (langkah)',
    'Focus Score',
    MICRO_MIN_POS,
    MICRO_MAX_POS,
    500
  );

  ConfigureLensResultChart(
    chtOtsuMicro10XResult,
    serOtsuMicro10XResult,
    'Nilai Otsu Mikrometer Objektif 10×',
    'Posisi Mikrometer (langkah)',
    'Nilai Otsu',
    MICRO_MIN_POS,
    MICRO_MAX_POS,
    500
  );

  ConfigureBestPointMarker(
    chtFocusMacro4XResult,
    FBestMacroMarker4X
  );

  ConfigureBestPointMarker(
    chtFocusMicro4XResult,
    FBestMicroMarker4X
  );

  ConfigureBestPointMarker(
    chtFocusMacro10XResult,
    FBestMacroMarker10X
  );

  ConfigureBestPointMarker(
    chtFocusMicro10XResult,
    FBestMicroMarker10X
  );

  ConfigureBestPointMarker(
    chtOtsuMacro4XResult,
    FBestMacroOtsuMarker4X
  );

  ConfigureBestPointMarker(
    chtOtsuMicro4XResult,
    FBestMicroOtsuMarker4X
  );

  ConfigureBestPointMarker(
    chtOtsuMacro10XResult,
    FBestMacroOtsuMarker10X
  );

  ConfigureBestPointMarker(
    chtOtsuMicro10XResult,
    FBestMicroOtsuMarker10X
  );

  FResult4XAvailable := False;
  FResult4XBestMacro := 0;
  FResult4XBestMicro := 0;
  FResult4XBestMacroFocus := 0;
  FResult4XBestFocus := 0;
  FResult4XBestMacroOtsu := 0;
  FResult4XBestMicroOtsu := 0;

  FResult10XAvailable := False;
  FResult10XBestMacro := 0;
  FResult10XBestMicro := 0;
  FResult10XBestMacroFocus := 0;
  FResult10XBestFocus := 0;
  FResult10XBestMacroOtsu := 0;
  FResult10XBestMicroOtsu := 0;

  { Grafik hasil dikosongkan hanya ketika aplikasi pertama kali dibuka.
    Saat Autofokus berikutnya dimulai, hasil objektif lain tidak dihapus. }
  serFocusMacro4XResult.Clear;
  serOtsuMacro4XResult.Clear;
  serFocusMicro4XResult.Clear;
  serOtsuMicro4XResult.Clear;

  serFocusMacro10XResult.Clear;
  serOtsuMacro10XResult.Clear;
  serFocusMicro10XResult.Clear;
  serOtsuMicro10XResult.Clear;

  pcLensResult.ActivePage :=
    tabLensResult4X;

  pcGraphResult4X.ActivePage :=
    tabFocusMacro4XResult;

  pcGraphResult10X.ActivePage :=
    tabFocusMacro10XResult;
end;

procedure TfrmMain.CopyLineSeriesData(
  ASource: TLineSeries;
  ADestination: TLineSeries
);
var
  I: Integer;
begin
  if (ASource = nil) or
     (ADestination = nil) then
  begin
    Exit;
  end;

  ADestination.Clear;

  for I := 0 to ASource.Count - 1 do
  begin
    ADestination.AddXY(
      ASource.XValue[I],
      ASource.YValue[I]
    );
  end;
end;

procedure TfrmMain.SaveCompletedAutoFocusResult;
begin
  { Hasil hanya disimpan setelah Autofokus selesai dengan sukses.
    Pemindaian yang dihentikan atau gagal tidak memanggil prosedur ini. }
  case FLensActive of
    1:
      begin
        CopyLineSeriesData(
          serFocus,
          serFocusMacro4XResult
        );

        CopyLineSeriesData(
          serOtsu,
          serOtsuMacro4XResult
        );

        CopyLineSeriesData(
          serFocusMicro,
          serFocusMicro4XResult
        );

        CopyLineSeriesData(
          serOtsuMicro,
          serOtsuMicro4XResult
        );

        FResult4XAvailable := True;
        FResult4XBestMacro :=
          FAutoFocusBestMacroPosition;
        FResult4XBestMicro :=
          FAutoFocusBestMicroPosition;
        FResult4XBestMacroFocus :=
          FAutoFocusBestMacroFocus;
        FResult4XBestFocus :=
          FAutoFocusBestMicroFocus;

        SetBestPointMarker(
          FBestMacroMarker4X,
          FResult4XBestMacro,
          FResult4XBestMacroFocus
        );

        SetBestPointMarker(
          FBestMicroMarker4X,
          FResult4XBestMicro,
          FResult4XBestFocus
        );

        if TryGetSeriesYAtX(
          serOtsuMacro4XResult,
          FResult4XBestMacro,
          FResult4XBestMacroOtsu
        ) then
        begin
          SetBestPointMarker(
            FBestMacroOtsuMarker4X,
            FResult4XBestMacro,
            FResult4XBestMacroOtsu
          );
        end
        else
        begin
          FBestMacroOtsuMarker4X.Clear;
        end;

        if TryGetSeriesYAtX(
          serOtsuMicro4XResult,
          FResult4XBestMicro,
          FResult4XBestMicroOtsu
        ) then
        begin
          SetBestPointMarker(
            FBestMicroOtsuMarker4X,
            FResult4XBestMicro,
            FResult4XBestMicroOtsu
          );
        end
        else
        begin
          FBestMicroOtsuMarker4X.Clear;
        end;

        UpdateLensResultSummary(1);

        chtFocusMacro4XResult.Repaint;
        chtOtsuMacro4XResult.Repaint;
        chtFocusMicro4XResult.Repaint;
        chtOtsuMicro4XResult.Repaint;

        pcLensResult.ActivePage :=
          tabLensResult4X;

        pcGraphResult4X.ActivePage :=
          tabFocusMacro4XResult;
      end;

    2:
      begin
        CopyLineSeriesData(
          serFocus,
          serFocusMacro10XResult
        );

        CopyLineSeriesData(
          serOtsu,
          serOtsuMacro10XResult
        );

        CopyLineSeriesData(
          serFocusMicro,
          serFocusMicro10XResult
        );

        CopyLineSeriesData(
          serOtsuMicro,
          serOtsuMicro10XResult
        );

        FResult10XAvailable := True;
        FResult10XBestMacro :=
          FAutoFocusBestMacroPosition;
        FResult10XBestMicro :=
          FAutoFocusBestMicroPosition;
        FResult10XBestMacroFocus :=
          FAutoFocusBestMacroFocus;
        FResult10XBestFocus :=
          FAutoFocusBestMicroFocus;

        SetBestPointMarker(
          FBestMacroMarker10X,
          FResult10XBestMacro,
          FResult10XBestMacroFocus
        );

        SetBestPointMarker(
          FBestMicroMarker10X,
          FResult10XBestMicro,
          FResult10XBestFocus
        );

        if TryGetSeriesYAtX(
          serOtsuMacro10XResult,
          FResult10XBestMacro,
          FResult10XBestMacroOtsu
        ) then
        begin
          SetBestPointMarker(
            FBestMacroOtsuMarker10X,
            FResult10XBestMacro,
            FResult10XBestMacroOtsu
          );
        end
        else
        begin
          FBestMacroOtsuMarker10X.Clear;
        end;

        if TryGetSeriesYAtX(
          serOtsuMicro10XResult,
          FResult10XBestMicro,
          FResult10XBestMicroOtsu
        ) then
        begin
          SetBestPointMarker(
            FBestMicroOtsuMarker10X,
            FResult10XBestMicro,
            FResult10XBestMicroOtsu
          );
        end
        else
        begin
          FBestMicroOtsuMarker10X.Clear;
        end;

        UpdateLensResultSummary(2);

        chtFocusMacro10XResult.Repaint;
        chtOtsuMacro10XResult.Repaint;
        chtFocusMicro10XResult.Repaint;
        chtOtsuMicro10XResult.Repaint;

        pcLensResult.ActivePage :=
          tabLensResult10X;

        pcGraphResult10X.ActivePage :=
          tabFocusMacro10XResult;
      end;
  end;

  UpdateSaveResultButtonState;
end;

procedure TfrmMain.InitializeCharts;
begin
  { Semua TabSheet, TChart, dan TLineSeries sudah dibuat melalui
    Form Designer sehingga juga terlihat pada tampilan Design.
    Bagian ini menyamakan tampilan keempat grafik agar lebih mudah dibaca. }

  tabFocusGraph.Caption := 'Focus Makro';
  tabOtsuGraph.Caption := 'Otsu Makro';
  tabFocusMicroGraph.Caption := 'Focus Mikro';
  tabOtsuMicroGraph.Caption := 'Otsu Mikro';

  { ---------- Pengaturan dasar seluruh chart ---------- }
  chtFocus.Align := alClient;
  chtOtsu.Align := alClient;
  chtFocusMicro.Align := alClient;
  chtOtsuMicro.Align := alClient;

  chtFocus.View3D := False;
  chtOtsu.View3D := False;
  chtFocusMicro.View3D := False;
  chtOtsuMicro.View3D := False;

  chtFocus.Legend.Visible := False;
  chtOtsu.Legend.Visible := False;
  chtFocusMicro.Legend.Visible := False;
  chtOtsuMicro.Legend.Visible := False;

  chtFocus.Title.Text.Clear;
  chtOtsu.Title.Text.Clear;
  chtFocusMicro.Title.Text.Clear;
  chtOtsuMicro.Title.Text.Clear;

  chtFocus.Title.Text.Add('Focus Score Makrometer terhadap Posisi');
  chtOtsu.Title.Text.Add('Nilai Otsu Makrometer terhadap Posisi');
  chtFocusMicro.Title.Text.Add('Focus Score Mikrometer terhadap Posisi');
  chtOtsuMicro.Title.Text.Add('Nilai Otsu Mikrometer terhadap Posisi');

  chtFocus.Title.Font.Size := 10;
  chtOtsu.Title.Font.Size := 10;
  chtFocusMicro.Title.Font.Size := 10;
  chtOtsuMicro.Title.Font.Size := 10;

  chtFocus.Title.Font.Style := [fsBold];
  chtOtsu.Title.Font.Style := [fsBold];
  chtFocusMicro.Title.Font.Style := [fsBold];
  chtOtsuMicro.Title.Font.Style := [fsBold];

  chtFocus.BottomAxis.Title.Caption := 'Posisi Makrometer (langkah)';
  chtOtsu.BottomAxis.Title.Caption := 'Posisi Makrometer (langkah)';
  chtFocusMicro.BottomAxis.Title.Caption := 'Posisi Mikrometer (langkah)';
  chtOtsuMicro.BottomAxis.Title.Caption := 'Posisi Mikrometer (langkah)';

  chtFocus.LeftAxis.Title.Caption := 'Focus Score';
  chtOtsu.LeftAxis.Title.Caption := 'Nilai Otsu';
  chtFocusMicro.LeftAxis.Title.Caption := 'Focus Score';
  chtOtsuMicro.LeftAxis.Title.Caption := 'Nilai Otsu';

  chtFocus.BottomAxis.Title.Font.Style := [fsBold];
  chtOtsu.BottomAxis.Title.Font.Style := [fsBold];
  chtFocusMicro.BottomAxis.Title.Font.Style := [fsBold];
  chtOtsuMicro.BottomAxis.Title.Font.Style := [fsBold];

  chtFocus.LeftAxis.Title.Font.Style := [fsBold];
  chtOtsu.LeftAxis.Title.Font.Style := [fsBold];
  chtFocusMicro.LeftAxis.Title.Font.Style := [fsBold];
  chtOtsuMicro.LeftAxis.Title.Font.Style := [fsBold];

  chtFocus.BottomAxis.LabelsFont.Size := 9;
  chtOtsu.BottomAxis.LabelsFont.Size := 9;
  chtFocusMicro.BottomAxis.LabelsFont.Size := 9;
  chtOtsuMicro.BottomAxis.LabelsFont.Size := 9;

  chtFocus.LeftAxis.LabelsFont.Size := 9;
  chtOtsu.LeftAxis.LabelsFont.Size := 9;
  chtFocusMicro.LeftAxis.LabelsFont.Size := 9;
  chtOtsuMicro.LeftAxis.LabelsFont.Size := 9;

  chtFocus.BottomAxis.Grid.Visible := True;
  chtOtsu.BottomAxis.Grid.Visible := True;
  chtFocusMicro.BottomAxis.Grid.Visible := True;
  chtOtsuMicro.BottomAxis.Grid.Visible := True;

  chtFocus.LeftAxis.Grid.Visible := True;
  chtOtsu.LeftAxis.Grid.Visible := True;
  chtFocusMicro.LeftAxis.Grid.Visible := True;
  chtOtsuMicro.LeftAxis.Grid.Visible := True;

  chtFocus.BottomAxis.Grid.Style := psDot;
  chtOtsu.BottomAxis.Grid.Style := psDot;
  chtFocusMicro.BottomAxis.Grid.Style := psDot;
  chtOtsuMicro.BottomAxis.Grid.Style := psDot;

  chtFocus.LeftAxis.Grid.Style := psDot;
  chtOtsu.LeftAxis.Grid.Style := psDot;
  chtFocusMicro.LeftAxis.Grid.Style := psDot;
  chtOtsuMicro.LeftAxis.Grid.Style := psDot;

  chtFocus.BottomAxis.AxisValuesFormat := '#,##0';
  chtOtsu.BottomAxis.AxisValuesFormat := '#,##0';
  chtFocusMicro.BottomAxis.AxisValuesFormat := '#,##0';
  chtOtsuMicro.BottomAxis.AxisValuesFormat := '#,##0';

  chtFocus.LeftAxis.AxisValuesFormat := '0.0##';
  chtFocusMicro.LeftAxis.AxisValuesFormat := '0.0##';
  chtOtsu.LeftAxis.AxisValuesFormat := '0';
  chtOtsuMicro.LeftAxis.AxisValuesFormat := '0';

  { ---------- Rentang sumbu X dibuat tetap agar tampilan seragam ---------- }
  chtFocus.BottomAxis.Automatic := False;
  chtOtsu.BottomAxis.Automatic := False;
  chtFocusMicro.BottomAxis.Automatic := False;
  chtOtsuMicro.BottomAxis.Automatic := False;

  chtFocus.BottomAxis.Minimum := MACRO_MIN_POS;
  chtFocus.BottomAxis.Maximum := MACRO_MAX_4X;
  chtFocus.BottomAxis.Increment := 500;

  chtOtsu.BottomAxis.Minimum := MACRO_MIN_POS;
  chtOtsu.BottomAxis.Maximum := MACRO_MAX_4X;
  chtOtsu.BottomAxis.Increment := 500;

  chtFocusMicro.BottomAxis.Minimum := -1600;
  chtFocusMicro.BottomAxis.Maximum := 1600;
  chtFocusMicro.BottomAxis.Increment := 500;

  chtOtsuMicro.BottomAxis.Minimum := -1600;
  chtOtsuMicro.BottomAxis.Maximum := 1600;
  chtOtsuMicro.BottomAxis.Increment := 500;

  { ---------- Sumbu Y seluruh grafik kembali otomatis ----------
    Rentang 0..255 pada Otsu sebelumnya membuat kurva terlihat terlalu
    gepeng karena data nyata hanya berada sekitar 100..130. Dengan mode
    otomatis, TeeChart menyesuaikan skala terhadap data sehingga pola
    perubahan lebih mudah dibaca. }
  chtFocus.LeftAxis.Automatic := True;
  chtOtsu.LeftAxis.Automatic := True;
  chtFocusMicro.LeftAxis.Automatic := True;
  chtOtsuMicro.LeftAxis.Automatic := True;

  chtFocus.LeftAxis.Increment := 0;
  chtOtsu.LeftAxis.Increment := 0;
  chtFocusMicro.LeftAxis.Increment := 0;
  chtOtsuMicro.LeftAxis.Increment := 0;

  { ---------- Gaya garis dan titik dibuat sama ---------- }
  serFocus.Title := 'Focus Makrometer';
  serOtsu.Title := 'Otsu Makrometer';
  serFocusMicro.Title := 'Focus Mikrometer';
  serOtsuMicro.Title := 'Otsu Mikrometer';

  serFocus.LinePen.Width := 2;
  serOtsu.LinePen.Width := 2;
  serFocusMicro.LinePen.Width := 2;
  serOtsuMicro.LinePen.Width := 2;

  serFocus.Pointer.Visible := True;
  serOtsu.Pointer.Visible := True;
  serFocusMicro.Pointer.Visible := True;
  serOtsuMicro.Pointer.Visible := True;

  serFocus.Pointer.HorizSize := 3;
  serOtsu.Pointer.HorizSize := 3;
  serFocusMicro.Pointer.HorizSize := 3;
  serOtsuMicro.Pointer.HorizSize := 3;

  serFocus.Pointer.VertSize := 3;
  serOtsu.Pointer.VertSize := 3;
  serFocusMicro.Pointer.VertSize := 3;
  serOtsuMicro.Pointer.VertSize := 3;

  serFocus.Marks.Visible := False;
  serOtsu.Marks.Visible := False;
  serFocusMicro.Marks.Visible := False;
  serOtsuMicro.Marks.Visible := False;

  ClearAllGraphSeries;
  pcGraphView.ActivePage := tabFocusGraph;

  ApplyActiveMacroRange;
  InitializeLensResultCharts;
end;

{ ============================================================================
  STATUS BAR
  ============================================================================ }

procedure TfrmMain.SetStatus(
  const AText: string
);
begin
  stbMain.SimplePanel := True;
  stbMain.SimpleText := AText;
end;

{ ============================================================================
  PENUTUPAN FORM
  ============================================================================ }

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FAutoFocusRunning := False;
  FAutoFocusStopRequested := True;
  FDualAutoFocusActive := False;
  FDualAutoFocusStopRequested := True;
  FDualAutoFocusStage := dafsIdle;

  FLensChangeState := lcsIdle;
  FLensTarget := 0;
  FLensMoving := False;
  FLensStopRequested := True;
  FZProfileSynchronized := False;

  if Assigned(FAutoFocusTimer) then
    FAutoFocusTimer.Enabled := False;

  StopLensVerificationTimer;

  if FCameraActive then
  begin
    try
      StopCamera;
    except
    end;
  end
  else
  begin
    try
      ocvCameraSource1.Enabled := False;
      ocvView1.VideoSource := nil;
    except
    end;
  end;

  if Assigned(FTcpReadTimer) then
    FTcpReadTimer.Enabled := False;

  DisconnectTcpClient('');

  { ComPort1 tetap ditutup bila pernah dipakai sebagai jalur servis lama. }
  if ComPort1.Connected then
  begin
    try
      ComPort1.Close;
    except
    end;
  end;

  if ComPortLens.Connected then
  begin
    try
      ComPortLens.Close;
    except
    end;
  end;
end;

end.
