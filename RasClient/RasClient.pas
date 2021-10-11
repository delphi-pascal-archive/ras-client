(*
   TRasClient версия 1.4 (с) 2008 Фёдор Сафронов <fyodors@gmail.com>

   TRasClient - компонент для простой работы с клиентскими возможностями RAS API.

   Под клиентскими возможностями подразумевается использование готового Dial-up или VPN соединения,
   уже имеющихся в системе, возможность контроля подключения, получение различной информации о
   соединении (типа ip адресов себя и сервера, номера телефона, кода страны и т.д.), и
   возможноть прервать соединение, даже созданное другой программой или пользователем.

   Модуль RasUnit, который я использую, создан Davide Moretti <dave@rimini.com>
   на основе ras.h - Remote Access external API - Copyright (c) 1992-1996, Microsoft Corporation,
   и модифицирован Alex Ilyin <alexil@pisem.net>, за что им отдельное спасибо, хотя
   мы и не знакомы.

   Вы используете компонент TRasClient на свой страх и риск. Автор и создатели модуля RasUnit
   не несут никакой ответственности за какой-либо ущерб, причиненный при использовании этого компонента.

   Компонент абсолютно бесплатен и распространяется свободно. Вы можете делать любые изменения в коде
   компонента, так, как Вам захочется. За сделанные Вами изменения автор и создатели модуля RasUnit
   также не несут никакой ответственности.

   Связаться с автором можно, отправив письмо на адрес <fyodors@gmail.com>

   Пояснения:
      1. Да, текст exception'ов написан по-русски. Желающие могут перевести на любой другой язык.
      2. Текст ошибок и статусов также на русском. Вольный перевод выполнен мной.
      3. Проверки на Self <> nil в каждой функции нужны для многопоточных приложений, т.к. даже после
         уничтожения всех объектов, разрушения стека потока и самого потока, RAS все еще пытается
         коннектиться и использовать функции. Желающие также могут переделать по своему усмотрению.
*)
unit RasClient;

interface

uses
   Classes, RasUnit;

type
   TRASEntry = class //класс для соединения RAS API
   private
      FOwner: TComponent;
      FHandle: THRasConn;
      FName: string;
      FDeviceName: string;
      FDeviceType: string;
      FClientIP: string;
      FServerIP: string;
      FPhoneNumb: string;
      FAreaCode: string;
      FCountryCode: integer;
      FConnected: boolean;
   protected
      procedure GetDialParams(var DialParams: TRasDialParams);
   public
      constructor Create(AOwner: TComponent; const AName: string);
      procedure GetProperties;

      procedure Connect;
      procedure Disconnect;
   published
      property Handle: THRasConn read FHandle;        //хэндл
      property Name: string read FName;               //имя соединения
      property DeviceName: string read FDeviceName;   //имя устройства
      property DeviceType: string read FDeviceType;   //тип устройства
      property ClientIP: string read FClientIP;
      property ServerIP: string read FServerIP;
      property PhoneNumber: string read FPhoneNumb;
      property AreaCode: string read FAreaCode;
      property CountryCode: integer read FCountryCode;
      property Connected: boolean read FConnected;
   end;

   TEntryList = class(TList)  //список экземпляров TRASEntry
   private
      FOwner: TComponent;
   protected
      function GetItem(Index: integer): TRASEntry;
      procedure PutItem(Index: integer; Value: TRASEntry);
   public
      constructor Create(AOwner: TComponent);
      destructor Destroy; override;

      procedure AddItem(AName: string);
      function IndexOf(Item: TRASEntry): integer;
      function IndexOfName(AName: string): integer;

      property Items[Index: integer]: TRASEntry read GetItem write PutItem; default;
   end;

   TConnectingEvent = procedure (Sender: TObject; const Name: string; Msg: Integer; State: Integer;
                                    Error: Longint) of object;
   TConnectEvent = procedure (Sender: TObject; const Name: string) of object;

   TRASClient = class(TComponent) //компонент
   private
      FEntries: TEntryList;

      FOnConnecting: TConnectingEvent;
      FOnConnected: TConnectEvent;
      FOnDisconnected: TConnectEvent;
   protected
      procedure GetRASEntries;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;

      procedure GetRASEntriesStatus; //определяет статус соединений (подключено/отключено), хэндл и ip
      procedure ClearRasEntriesStatus; //очищает статус соединений
      function GetStatusString(State: Integer): string;
      function GetErrorString(Error: Integer): string;

      property Entries: TEntryList read FEntries write FEntries;
   published
      property OnConnecting: TConnectingEvent read FOnConnecting write FOnConnecting;
      property OnDisconnected: TConnectEvent read FOnDisconnected write FOnDisconnected;
      property OnConnected: TConnectEvent read FOnConnected write FOnConnected;
   end;

   procedure Register; //регистрация компонента

implementation

uses
   Windows, SysUtils;

var
   RASComponent: TRASClient;
   RASCurrEntryName: string;

// ***** Register component ***** //

procedure Register;
begin
   RegisterComponents('RAS API', [TRASClient]);
end;

// ***** Callback for RasDial ***** //

procedure DialCallback(Msg: Integer; State: TRasConnState; Error: Longint); stdcall;
begin
   if RASComponent <> nil then
   begin
      if Assigned(RASComponent.FOnConnecting) then
         RASComponent.FOnConnecting(RASComponent, RASCurrEntryName, Msg, State, Error);

      if (State = $2000) and (Error = 0) then
      begin // Если соединение успешно установлено...
         RASComponent.Entries[RASComponent.Entries.IndexOfName(RASCurrEntryName)].FConnected := true;
         if Assigned(RASComponent.FOnConnected) then
            RASComponent.FOnConnected(RASComponent, RASCurrEntryName);
      end;
   end;
end;

// ***** TEntry implementation ***** //

constructor TRASEntry.Create(AOwner: TComponent; const AName: string);
begin
   inherited Create;

   if AOwner = nil then
      Raise Exception.Create('Не допускается создание экземпляра класса TRASEntry с пустым владельцем');

   FOwner := AOwner;
   FHandle := 0;
   FName := AName;
   FDeviceName:= '';
   FDeviceType := '';
   FClientIP := '0.0.0.0';
   FServerIP := '0.0.0.0';
   FPhoneNumb := '';
   FAreaCode := '';
   FCountryCode := 0;
   FConnected := false;
end;

procedure TRASEntry.GetProperties;
var
   EntryInfoSize, DeviceInfoSize: Integer;
   Entry: RasUnit.TRasEntry;
begin
   if Self = nil then
      Exit;

   EntryInfoSize := 0;
   DeviceInfoSize := 0;
   if ERROR_BUFFER_TOO_SMALL = RasGetEntryProperties(nil, PChar(FName), nil, EntryInfoSize, nil, DeviceInfoSize) then
   begin // первый вызов функции RasGetEntryProperties определяет размер буфера для свойств
      Entry.dwSize := sizeof(Entry);

      if 0 = RasGetEntryProperties(nil, PChar(FName), Pointer(@Entry), EntryInfoSize, nil, DeviceInfoSize) then
      begin // второй вызов дает сами свойства
         FDeviceName := Entry.szDeviceName;
         FDeviceType := Entry.szDeviceType;
         FPhoneNumb := Entry.szLocalPhoneNumber;
         FAreaCode := Entry.szAreaCode;
         FCountryCode := Entry.dwCountryCode;
      end
      else
         Exception.CreateFmt('Невозможно получить свойства подключения "%s" удаленного доступа',[FName]);
   end
   else
      Raise Exception.CreateFmt('Невозможно получить свойства подключения "%s" удаленного доступа',[FName]);
end;

procedure TRASEntry.GetDialParams(var DialParams: TRasDialParams);
var
   FlagPassw: LongBool;
begin
   if Self = nil then
      Exit;

   ZeroMemory(@DialParams, sizeof(DialParams));
   DialParams.dwSize := sizeof(DialParams);
   StrPCopy(DialParams.szEntryName, FName);

   if RasGetEntryDialParams(nil, DialParams, FlagPassw) <> 0 then
      Raise Exception.CreateFmt('Невозможно получить параметры дозвона для соединения "%s"', [FName]);
end;

procedure TRASEntry.Connect;
var
   DialParams: TRasDialParams;
begin
   if (not FConnected) and (Self <> nil) then
   begin
      RASComponent := TRASClient(FOwner);
      RASCurrEntryName := FName;

      GetDialParams(DialParams);
      RasDial(nil, nil, DialParams, 0, @DialCallback, FHandle);
   end;
end;

procedure TRASEntry.Disconnect;
var
   Status: TRasConnStatus;
begin
   if (FConnected) and (FHandle <> 0) and (Self <> nil) then
   begin
      ZeroMemory(@Status, sizeof(Status));
      Status.dwSize := sizeof(Status);

      RasHangup(FHandle);
      while ERROR_INVALID_HANDLE <> RasGetConnectStatus(FHandle, Status) do
         Sleep(0);

      FHandle := 0;
      FConnected := false;

      RASComponent := TRASClient(FOwner);
      RASCurrEntryName := FName;
      if Assigned(RASComponent.FOnDisconnected) then
         RASComponent.FOnDisconnected(RASComponent, RASCurrEntryName);
   end;
end;

// ***** TEntryList implementation ***** //

constructor TEntryList.Create(AOwner: TComponent);
begin
   inherited Create;

   if AOwner = nil then
      Raise Exception.Create('Не допускается создание экземпляра класса TEntryList с пустым владельцем');

   FOwner := AOwner;
end;

destructor TEntryList.Destroy;
var
   i: integer;
begin
   if Self = nil then
      Exit;
       
   for i := 0 to Pred(Count) do
   begin
      TRasEntry(inherited Items[i]).Free;
      inherited Items[i] := nil;
   end;

   inherited Destroy;
end;

function TEntryList.GetItem(Index: Integer): TRASEntry;
begin
   if Self = nil then
   begin
      Result := nil;
      Exit;
   end;

   Result := TRASEntry(inherited Items[Index]);
end;

procedure TEntryList.PutItem(Index: Integer; Value: TRASEntry);
begin
   if Self = nil then
      Exit;

   inherited Items[Index] := Pointer(Value);
end;

procedure TEntryList.AddItem(AName: string);
var
   Tmp: TRASEntry;
begin
   if Self = nil then
      Exit;
      
   Tmp := TRASEntry.Create(FOwner, AName);

   if IndexOf(Tmp) = -1 then
   begin
      Add(Pointer(Tmp));
   end;
end;

function TEntryList.IndexOf(Item: TRASEntry): integer;
begin
   if Self = nil then
   begin
      Result := -1;
      Exit;
   end;

   Result := inherited IndexOf(Pointer(Item));
end;

function TEntryList.IndexOfName(AName: string): integer;
var
   i: integer;
begin
   Result := -1;

   if Self = nil then
      Exit;

   for i := 0 to Pred(Count) do
   begin
      if Items[i].Name = AName then
      begin
         Result := i;
         break;
      end;
   end;
end;

// ***** TRASClient implementation ***** //

constructor TRASClient.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);

   FEntries := TEntryList.Create(Self);
   GetRASEntries;
   GetRASEntriesStatus;
end;

destructor TRASClient.Destroy;
begin
   if Self = nil then
      Exit;

   if FEntries <> nil then
      FreeAndNil(FEntries);
      
   RASComponent := nil;

   inherited Destroy;
end;

procedure TRASClient.GetRASEntriesStatus;
var
   RasConn: array of TRasConn;
   iBuffSize, iConn, iRetValue: integer;
   i: integer;
   RASPppIp: TRasPppIp;
   bOK: boolean;
begin
   if Self = nil then
      Exit;
      
   SetLength(RasConn, 1);
   iBuffSize := sizeof(TRasConn);
   RasConn[0].dwSize := iBuffSize;
   iConn := 0;

   iRetValue := RasEnumConnections(@RasConn[0], iBuffSize, iConn); // определяем количество соединений и размер буфера
   case iRetValue of
      0: bOK := true;
      ERROR_BUFFER_TOO_SMALL: bOK := true;
      else
         bOK := false;
   end;

   if iConn > 0 then
   begin
      if bOK then
      begin
         SetLength(RasConn, iConn); //получаем информацию о соединениях
         if 0 = RasEnumConnections(@RasConn[0], iBuffSize, iConn) then
         begin
            for i := 0 to Pred(iConn) do //ищем нужное соединение в нашем списке
            begin
               if FEntries.IndexOfName(RasConn[i].szEntryName) <= -1 then
                  Raise Exception.CreateFmt('Активное соединение "%s" не найдено',[RasConn[i].szEntryName]);

               with FEntries[FEntries.IndexOfName(RasConn[i].szEntryName)] do
               begin
                  FConnected := true; //ставим статус
                  FHandle := RasConn[i].hrasconn; // ставим хэндл

                  iBuffSize := sizeof(RASPppIp);
                  RASPppIp.dwSize := iBuffSize;
                  if 0 = RasGetProjectionInfo(FHandle, RASP_PppIp, Pointer(@RasPppIp), iBuffSize) then
                  begin // и получаем для соединения ip адреса сервера и клиента
                     FClientIP := RASPppIp.szIpAddress;
                     FServerIP := RASPppIp.szServerIpAddress;
                  end;
               end;
            end;
         end
         else
            Raise Exception.Create('Ошибка при определении активных соединений');
      end
      else
         Raise Exception.Create('Ошибка при определении активных соединений');
   end;
end;

procedure TRASClient.GetRASEntries;
var
   EntryNames: array of TRasEntryName;
   iBuffSize: Integer;
   iEntries: Integer;
   iRetValue: integer;
   i: Integer;
   bOK: boolean;
begin
   if Self = nil then
      Exit;

   SetLength(EntryNames, 1);
   EntryNames[0].dwSize := sizeof(TRasEntryName);
   iBuffSize := sizeof(TRasEntryName);
   iEntries := 0;

   iRetValue := RasEnumEntries(nil, nil, @EntryNames[0], iBuffSize, iEntries);
   // Первый вызов функции RasEnumEntries определил количество соединений
   case iRetValue of
      0: bOK := true;
      ERROR_BUFFER_TOO_SMALL: bOK := true;
      else
         bOK := false;
   end;

   if iEntries > 0 then
   begin
      if bOK then
      begin
         SetLength(EntryNames, iEntries);
         EntryNames[0].dwSize := sizeof(TRasEntryName);
         iBuffSize := sizeof(TRasEntryName) * iEntries;

         if 0 = RasEnumEntries(nil, nil, @EntryNames[0], iBuffSize, iEntries) then
         begin // Второй вызов дал имена этих соединений
            for i := 0 to Pred(iEntries) do
            begin //Заполняем класс списка найденными соединениями
               Entries.AddItem(EntryNames[i].szEntryName);
               Entries.Items[i].GetProperties; //Статус соединений (подключено/отключено)
            end;
         end
         else
            raise Exception.Create('Невозможно инициализировать телефонные книги удаленного доступа');
      end
      else
         raise Exception.Create('Невозможно инициализировать телефонные книги удаленного доступа');
   end;
end;

procedure TRASClient.ClearRasEntriesStatus;
var
   i: integer;
begin
   if Self = nil then
      Exit;
      
   for i := 0 to Pred(FEntries.Count) do
   begin
      FEntries[i].FHandle := 0;
      FEntries[i].FConnected := false;
      FEntries[i].FClientIP := '0.0.0.0';
      FEntries[i].FServerIP := '0.0.0.0';
   end;
end;

function TRASClient.GetStatusString(State: Integer): string;
begin
  case State of
      RASCS_OpenPort:            Result := 'Установка связи. Попытка открытия порта';
      RASCS_PortOpened:          Result := 'Установка связи. Порт открыт';
      RASCS_ConnectDevice:       Result := 'Установка связи. Попытка установки связи';
      RASCS_DeviceConnected:     Result := 'Установка связи. Связь установлена';
      RASCS_AllDevicesConnected: Result := 'Установка связи. Установка связи подтверждена';
      RASCS_Authenticate:        Result := 'Аутентификация. Начата процедура аутентификации';
      RASCS_AuthNotify:          Result := 'Аутентификация. Сообщение при аутентификации';
      RASCS_AuthRetry:           Result := 'Аутентификация. Попытка повторной аутентификации';
      RASCS_AuthCallback:        Result := 'Аутентификация. Запрос проверки номера для обратного вызова';
      RASCS_AuthChangePassword:  Result := 'Аутентификация. Запрос смены пароля';
      RASCS_AuthProject:         Result := 'Аутентификация. Процедура проверки аутентификации';
      RASCS_AuthLinkSpeed:       Result := 'Установка связи. Расчет скорости соединения';
      RASCS_AuthAck:             Result := 'Аутентификация. Запрос аутентификации подтвержден';
      RASCS_ReAuthenticate:      Result := 'Аутентификация. Повторная аутентификация';
      RASCS_Authenticated:       Result := 'Аутентификация. Аутентификация подтверждена';
      RASCS_PrepareForCallback:  Result := 'Обратный вызов. Попытка обрыва связи для процедуры обратного вызова';
      RASCS_WaitForModemReset:   Result := 'Обратный вызов. Ожидание сброса модема';
      RASCS_WaitForCallback:     Result := 'Обратный вызов. Ожидание обратного вызова от сервера';
      RASCS_Projected:           Result := 'Аутентификация. Процедура проверки аутентификации завершена';
      RASCS_StartAuthentication: Result := 'Аутентификация. Начата процедура аутентификации';
      RASCS_CallbackComplete:    Result := 'Обратный вызов. Обратный вызов выполнен';
      RASCS_LogonNetwork:        Result := 'Установка связи. Регистрация в сети';
      
      RASCS_Interactive:         Result := 'Interactive';
      RASCS_RetryAuthentication: Result := 'Retry Authentication';
      RASCS_CallbackSetByCaller: Result := 'Callback set by caller';
      RASCS_PasswordExpired:     Result := 'Password Expired';
      
      RASCS_Connected:           Result := 'Удаленное соединение установлено';
      RASCS_Disconnected:        Result := 'Удаленное соединение завершено';
    else
      Result := 'Неизвестный статус';
  end;
end;

function TRASClient.GetErrorString(Error: Integer): string;
var
   sErr: array [0..255] of char;
begin
   case Error of
      0: Result := 'OK';
      RASBASE+1: Result := 'Обнаружен неверный дескриптор порта';
      RASBASE+2: Result := 'Указаный порт уже открыт';
      RASBASE+3: Result := 'Буфер клиента слишком мал';
      RASBASE+4: Result := 'Передана неверная информация';
      RASBASE+5: Result := 'Данные для порта не установлены';
      RASBASE+6: Result := 'Указанные порт не присоединен';
      RASBASE+7: Result := 'Обнаружено неверное событие';
      RASBASE+8: Result := 'Указанное устройство отсутствует в системе';
      RASBASE+9: Result := 'Тип указанного устройства отсутствует в системе';
      RASBASE+10: Result := 'Указан неверный буфер';
      RASBASE+11: Result := 'Указанный маршрут не доступен';
      RASBASE+12: Result := 'Указанный маршрут не был определен';
      RASBASE+13: Result := 'Указан неверный тип сжатия данных';
      RASBASE+14: Result := 'Не доступно нужное количество буферов';
      RASBASE+15: Result := 'Указанный порт не найден в системе';
      RASBASE+16: Result := 'Обнаружен незавершенный асинхронный запрос';
      RASBASE+17: Result := 'Устройство уже завершило связь';
      RASBASE+18: Result := 'Указанный порт не открыт';
      RASBASE+19: Result := 'Связь с удаленным компьютером не установлена и порт закрыт';
      RASBASE+20: Result := 'Конечные точки не определены';
      RASBASE+21: Result := 'Не удалось открыть файл телефонной книги';
      RASBASE+22: Result := 'Не удалось загрузить файл телефонной книги';
      RASBASE+23: Result := 'Не удалось обнаружить запись в телефонной книге для данного соединения';
      RASBASE+24: Result := 'Не удалось обновить файл телефонной книги';
      RASBASE+25: Result := 'Обнаружена неверная информация в файле телефонной книги';
      RASBASE+26: Result := 'Не удалось загрузить строку';
      RASBASE+27: Result := 'Не удалось найти ключ';
      RASBASE+28: Result := 'Соединение было оборвано удаленным компьютером до того, как было завершено';
      RASBASE+29: Result := 'Соединение было закрыто удаленным компьютером';
      RASBASE+30: Result := 'Устройство завершило связь из-за аппаратной ошибки';
      RASBASE+31: Result := 'Пользователь завершил связь';
      RASBASE+32: Result := 'Обнаружен неверный размер структуры';
      RASBASE+33: Result := 'Устройство уже используется или не настроено на работу в режиме удаленного доступа';
      RASBASE+34: Result := 'Компьютер не был зарегистрирован в сети';
      RASBASE+35: Result := 'Неизвестная ошибка';
      RASBASE+36: Result := 'Устройство присоединено к порту не того типа';
      RASBASE+37: Result := 'Обнаружена неизменяемая строка';
      RASBASE+38: Result := 'Удаленный сервер не ответил за время сеанса';
      RASBASE+43: Result := 'Ошибка сетевого адаптера сервера';
      RASBASE+45: Result := 'Внутренняя ошибка аутентификации';
      RASBASE+46: Result := 'В это время запрещено использовать соединение';
      RASBASE+47: Result := 'Соединение отключено';
      RASBASE+48: Result := 'Срок действия пароля истек';
      RASBASE+49: Result := 'У пользователя нет прав на установку удаленных соединений';
      RASBASE+50: Result := 'Удаленный сервер не отвечает';
      RASBASE+51: Result := 'Ошибка устройства';
      RASBASE+52: Result := 'Неизвестный отклик от устройства';
      RASBASE+65: Result := 'Устройство не настроено на работу в режиме удаленного доступа';
      RASBASE+66: Result := 'Устройство не фунционирует';
      RASBASE+68: Result := 'Соединение разорвано';
      RASBASE+76: Result := 'Телефонная линия занята';
      RASBASE+77: Result := 'Обнаружен ответ голосом';
      RASBASE+78: Result := 'Удаленный компьютер не ответил на попытку соединения';
      RASBASE+79: Result := 'Нет несущей в телефонной линии';
      RASBASE+80: Result := 'Нет тонального сигнала в телефонной линии';
      RASBASE+81: Result := 'Устройство сообщило об ошибке';
      RASBASE+91: Result := 'Доступ запрещен. Имя пользователя и/или пароль не найдены в домене';
      RASBASE+92: Result := 'Аппаратная ошибка устройства';
      RASBASE+108: Result := 'Срок действия учетной записи истек';
      RASBASE+109: Result := 'Ошибка при попытке смене пароля';
      RASBASE+115: Result := 'Слишком много ошибок - плохое качество телефонной линии';
      RASBASE+118: Result := 'Превышен срок ожидания ответа от сервера';
      RASBASE+119: Result := 'Cоединение прервано удаленным компьютером';
      RASBASE+120: Result := 'Невозможно установить соединение с удаленным компьютером. Возможно неверны настройки сети';
      RASBASE+121: Result := 'Удаленный компьютер не отвечает';
      RASBASE+122: Result := 'От удаленного компьютера получены неверные данные';
      RASBASE+128: Result := 'Системе не удается найти адаптер протокола IP';
      RASBASE+129: Result := 'SLIP cannot be used unless the IP protocol is installed';
      RASBASE+130: Result := 'Регистрация компьютера в сети не завершена';
      RASBASE+131: Result := 'Протокол не настроен на работу в режиме удаленного доступа';
      RASBASE+138: Result := 'Удаленный сервер не выделил IP-адрес';
      RASBASE+139: Result := 'Протокол безопасности не позволяет использовать пароль, сохраненный Windows. Требуется ручной ввод пароля';
      else
      begin
      	RasGetErrorString(Error, @sErr[0], 256);
      	Result := sErr;	
      end;
   end;
end;

end.

