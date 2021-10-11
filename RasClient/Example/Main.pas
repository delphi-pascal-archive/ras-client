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

 // Здесь храним индекс соединения
 CurrEntry:=cbConnections.ItemIndex;

 if CurrEntry>-1 //если есть к чему коннектиться
 then
  begin
   // На тот случай, если статус был изменен другой прогой или пользователем:
   RAS.ClearRasEntriesStatus; // Очищаем статус соединений (подключено / отключено)
   RAS.GetRASEntriesStatus;   // И получаем его снова.
   RAS.Entries[CurrEntry].Connect; // Коннектимся к выбранному соединению
  end;
end;

procedure TMainForm.bDisconnectClick(Sender: TObject);
begin
   if CurrEntry > -1 then //если есть от чего отключаться.
      RAS.Entries[CurrEntry].Disconnect; //Отключаемся.
end;

procedure TMainForm.Button1Click(Sender: TObject);
var
   i: integer;
begin
   RAS.ClearRasEntriesStatus; //Очищаем статус соединений (подключено / отключено)
   RAS.GetRASEntriesStatus; // И получаем его снова.

   // Разрываем все установленные соединения
   for i := 0 to Pred(RAS.Entries.Count) do
      RAS.Entries[i].Disconnect;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
   i: integer;
begin
   //Пишем в ComboBox имена всех Dialup и VPN соединений в системе
   for i := 0 to Pred(RAS.Entries.Count) do
      cbConnections.Items.Add(RAS.Entries[i].Name);

   if cbConnections.Items.Count > 0 then
      cbConnections.ItemIndex := 0;
end;

procedure TMainForm.RASConnected(Sender: TObject; const Name: string);
begin
   // Событие, если соединение установлено.

   (Sender as TRASClient).GetRASEntriesStatus; // получаем информацию о соединениии
   lbLog.Items.Add(Format('Соединиение %s установлено',[Name]));
   // пишем в лог ip адреса.
   lbLog.Items.Add(Format('IP адрес сервера - %s',[(Sender as TRASClient).Entries[CurrEntry].ServerIP]));
   lbLog.Items.Add(Format('IP адрес клиента (себя) - %s',[(Sender as TRASClient).Entries[CurrEntry].ClientIP]));
end;

procedure TMainForm.RASConnecting(Sender: TObject; const Name: string; Msg, State, Error: Integer);
begin
   // Это событие происходит несколько раз во время процесса соединения...

   if Error = 0 then // если все идет нормально
   begin // пишем в лог статус (получив строку из номера статуса)
      lbLog.Items.Add(Format('%s - %s',[Name, (Sender as TRASClient).GetStatusString(State)]));
   end
   else // если ошибка
   begin //пишем в лог ошибку
      lbLog.Items.Add(Format('%s: Ошибка %u - %s',[Name, Error, (Sender as TRASClient).GetErrorString(Error)]));
      // и разрываем соединение (хотя его и не должно еще быть).
      // Специально не использую переменную CurrEntry, а получаю индекс из имени соединения.
      (Sender as TRASClient).Entries[(Sender as TRASClient).Entries.IndexOfName(Name)].Disconnect;
   end;
end;

procedure TMainForm.RASDisconnected(Sender: TObject; const Name: string);
begin
   // Cобытие, если соединение завершено.
   // Происходит не сразу после нажатия кнопки!!! Через 1-2 секунды.
   lbLog.Items.Add(Format('Соединение %s завершено',[Name]));
end;

end.
