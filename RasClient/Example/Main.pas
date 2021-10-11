unit Main;

interface

uses
   Classes, Forms, Controls, StdCtrls, SysUtils, RasClient;

type
   TMainForm = class(TForm)
      RAS: TRASClient;
      lbLog: TListBox;
      GroupBox1: TGroupBox;
      cbConnections: TComboBox;
      bConnect: TButton;
      bDisconnect: TButton;
      Button1: TButton;
      procedure FormCreate(Sender: TObject);
      procedure bConnectClick(Sender: TObject);
      procedure bDisconnectClick(Sender: TObject);
      procedure RASConnecting(Sender: TObject; const Name: string; Msg, State, Error: Integer);
      procedure RASConnected(Sender: TObject; const Name: string);
      procedure RASDisconnected(Sender: TObject; const Name: string);
      procedure Button1Click(Sender: TObject);
   private
      { Private declarations }
   public
      { Public declarations }
   end;

var
   MainForm: TMainForm;
   CurrEntry: integer;

implementation

{$R *.dfm}

procedure TMainForm.bConnectClick(Sender: TObject);
begin
 lbLog.Clear;

 // ����� ������ ������ ����������
 CurrEntry:=cbConnections.ItemIndex;

 if CurrEntry>-1 //���� ���� � ���� ������������
 then
  begin
   // �� ��� ������, ���� ������ ��� ������� ������ ������ ��� �������������:
   RAS.ClearRasEntriesStatus; // ������� ������ ���������� (���������� / ���������)
   RAS.GetRASEntriesStatus;   // � �������� ��� �����.
   RAS.Entries[CurrEntry].Connect; // ����������� � ���������� ����������
  end;
end;

procedure TMainForm.bDisconnectClick(Sender: TObject);
begin
   if CurrEntry > -1 then //���� ���� �� ���� �����������.
      RAS.Entries[CurrEntry].Disconnect; //�����������.
end;

procedure TMainForm.Button1Click(Sender: TObject);
var
   i: integer;
begin
   RAS.ClearRasEntriesStatus; //������� ������ ���������� (���������� / ���������)
   RAS.GetRASEntriesStatus; // � �������� ��� �����.

   // ��������� ��� ������������� ����������
   for i := 0 to Pred(RAS.Entries.Count) do
      RAS.Entries[i].Disconnect;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
   i: integer;
begin
   //����� � ComboBox ����� ���� Dialup � VPN ���������� � �������
   for i := 0 to Pred(RAS.Entries.Count) do
      cbConnections.Items.Add(RAS.Entries[i].Name);

   if cbConnections.Items.Count > 0 then
      cbConnections.ItemIndex := 0;
end;

procedure TMainForm.RASConnected(Sender: TObject; const Name: string);
begin
   // �������, ���� ���������� �����������.

   (Sender as TRASClient).GetRASEntriesStatus; // �������� ���������� � �����������
   lbLog.Items.Add(Format('����������� %s �����������',[Name]));
   // ����� � ��� ip ������.
   lbLog.Items.Add(Format('IP ����� ������� - %s',[(Sender as TRASClient).Entries[CurrEntry].ServerIP]));
   lbLog.Items.Add(Format('IP ����� ������� (����) - %s',[(Sender as TRASClient).Entries[CurrEntry].ClientIP]));
end;

procedure TMainForm.RASConnecting(Sender: TObject; const Name: string; Msg, State, Error: Integer);
begin
   // ��� ������� ���������� ��������� ��� �� ����� �������� ����������...

   if Error = 0 then // ���� ��� ���� ���������
   begin // ����� � ��� ������ (������� ������ �� ������ �������)
      lbLog.Items.Add(Format('%s - %s',[Name, (Sender as TRASClient).GetStatusString(State)]));
   end
   else // ���� ������
   begin //����� � ��� ������
      lbLog.Items.Add(Format('%s: ������ %u - %s',[Name, Error, (Sender as TRASClient).GetErrorString(Error)]));
      // � ��������� ���������� (���� ��� � �� ������ ��� ����).
      // ���������� �� ��������� ���������� CurrEntry, � ������� ������ �� ����� ����������.
      (Sender as TRASClient).Entries[(Sender as TRASClient).Entries.IndexOfName(Name)].Disconnect;
   end;
end;

procedure TMainForm.RASDisconnected(Sender: TObject; const Name: string);
begin
   // C������, ���� ���������� ���������.
   // ���������� �� ����� ����� ������� ������!!! ����� 1-2 �������.
   lbLog.Items.Add(Format('���������� %s ���������',[Name]));
end;

end.
