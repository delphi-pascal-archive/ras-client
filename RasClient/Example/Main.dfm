object MainForm: TMainForm
  Left = 225
  Top = 132
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'TRASClient Example'
  ClientHeight = 355
  ClientWidth = 610
  Color = clBtnFace
  Font.Charset = RUSSIAN_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 120
  TextHeight = 16
  object lbLog: TListBox
    Left = 264
    Top = 8
    Width = 337
    Height = 339
    ExtendedSelect = False
    ItemHeight = 16
    TabOrder = 0
  end
  object GroupBox1: TGroupBox
    Left = 8
    Top = 8
    Width = 249
    Height = 65
    Caption = 'Connections'
    TabOrder = 1
    object cbConnections: TComboBox
      Left = 8
      Top = 24
      Width = 233
      Height = 24
      Style = csDropDownList
      ItemHeight = 16
      TabOrder = 0
    end
  end
  object bConnect: TButton
    Left = 8
    Top = 88
    Width = 121
    Height = 25
    Caption = 'Connect'
    TabOrder = 2
    OnClick = bConnectClick
  end
  object bDisconnect: TButton
    Left = 136
    Top = 88
    Width = 121
    Height = 25
    Caption = 'Disconnect'
    TabOrder = 3
    OnClick = bDisconnectClick
  end
  object Button1: TButton
    Left = 8
    Top = 120
    Width = 249
    Height = 25
    Caption = 'Disconnect all'
    TabOrder = 4
    OnClick = Button1Click
  end
  object RAS: TRASClient
    OnConnecting = RASConnecting
    OnDisconnected = RASDisconnected
    OnConnected = RASConnected
    Left = 272
    Top = 16
  end
end
