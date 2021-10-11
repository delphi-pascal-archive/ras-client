(*
   TRasClient ������ 1.4 (�) 2008 Ը��� �������� <fyodors@gmail.com>

   TRasClient - ��������� ��� ������� ������ � ����������� ������������� RAS API.

   ��� ����������� ������������� ��������������� ������������� �������� Dial-up ��� VPN ����������,
   ��� ��������� � �������, ����������� �������� �����������, ��������� ��������� ���������� �
   ���������� (���� ip ������� ���� � �������, ������ ��������, ���� ������ � �.�.), �
   ���������� �������� ����������, ���� ��������� ������ ���������� ��� �������������.

   ������ RasUnit, ������� � ���������, ������ Davide Moretti <dave@rimini.com>
   �� ������ ras.h - Remote Access external API - Copyright (c) 1992-1996, Microsoft Corporation,
   � ������������� Alex Ilyin <alexil@pisem.net>, �� ��� �� ��������� �������, ����
   �� � �� �������.

   �� ����������� ��������� TRasClient �� ���� ����� � ����. ����� � ��������� ������ RasUnit
   �� ����� ������� ��������������� �� �����-���� �����, ����������� ��� ������������� ����� ����������.

   ��������� ��������� ��������� � ���������������� ��������. �� ������ ������ ����� ��������� � ����
   ����������, ���, ��� ��� ���������. �� ��������� ���� ��������� ����� � ��������� ������ RasUnit
   ����� �� ����� ������� ���������������.

   ��������� � ������� �����, �������� ������ �� ����� <fyodors@gmail.com>

   ���������:
      1. ��, ����� exception'�� ������� ��-������. �������� ����� ��������� �� ����� ������ ����.
      2. ����� ������ � �������� ����� �� �������. ������� ������� �������� ����.
      3. �������� �� Self <> nil � ������ ������� ����� ��� ������������� ����������, �.�. ���� �����
         ����������� ���� ��������, ���������� ����� ������ � ������ ������, RAS ��� ��� ��������
         ������������ � ������������ �������. �������� ����� ����� ���������� �� ������ ����������.
*)
unit RasClient;

interface

uses
   Classes, RasUnit;

type
   TRASEntry = class //����� ��� ���������� RAS API
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
      property Handle: THRasConn read FHandle;        //�����
      property Name: string read FName;               //��� ����������
      property DeviceName: string read FDeviceName;   //��� ����������
      property DeviceType: string read FDeviceType;   //��� ����������
      property ClientIP: string read FClientIP;
      property ServerIP: string read FServerIP;
      property PhoneNumber: string read FPhoneNumb;
      property AreaCode: string read FAreaCode;
      property CountryCode: integer read FCountryCode;
      property Connected: boolean read FConnected;
   end;

   TEntryList = class(TList)  //������ ����������� TRASEntry
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

   TRASClient = class(TComponent) //���������
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

      procedure GetRASEntriesStatus; //���������� ������ ���������� (����������/���������), ����� � ip
      procedure ClearRasEntriesStatus; //������� ������ ����������
      function GetStatusString(State: Integer): string;
      function GetErrorString(Error: Integer): string;

      property Entries: TEntryList read FEntries write FEntries;
   published
      property OnConnecting: TConnectingEvent read FOnConnecting write FOnConnecting;
      property OnDisconnected: TConnectEvent read FOnDisconnected write FOnDisconnected;
      property OnConnected: TConnectEvent read FOnConnected write FOnConnected;
   end;

   procedure Register; //����������� ����������

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
      begin // ���� ���������� ������� �����������...
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
      Raise Exception.Create('�� ����������� �������� ���������� ������ TRASEntry � ������ ����������');

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
   begin // ������ ����� ������� RasGetEntryProperties ���������� ������ ������ ��� �������
      Entry.dwSize := sizeof(Entry);

      if 0 = RasGetEntryProperties(nil, PChar(FName), Pointer(@Entry), EntryInfoSize, nil, DeviceInfoSize) then
      begin // ������ ����� ���� ���� ��������
         FDeviceName := Entry.szDeviceName;
         FDeviceType := Entry.szDeviceType;
         FPhoneNumb := Entry.szLocalPhoneNumber;
         FAreaCode := Entry.szAreaCode;
         FCountryCode := Entry.dwCountryCode;
      end
      else
         Exception.CreateFmt('���������� �������� �������� ����������� "%s" ���������� �������',[FName]);
   end
   else
      Raise Exception.CreateFmt('���������� �������� �������� ����������� "%s" ���������� �������',[FName]);
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
      Raise Exception.CreateFmt('���������� �������� ��������� ������� ��� ���������� "%s"', [FName]);
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
      Raise Exception.Create('�� ����������� �������� ���������� ������ TEntryList � ������ ����������');

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

   iRetValue := RasEnumConnections(@RasConn[0], iBuffSize, iConn); // ���������� ���������� ���������� � ������ ������
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
         SetLength(RasConn, iConn); //�������� ���������� � �����������
         if 0 = RasEnumConnections(@RasConn[0], iBuffSize, iConn) then
         begin
            for i := 0 to Pred(iConn) do //���� ������ ���������� � ����� ������
            begin
               if FEntries.IndexOfName(RasConn[i].szEntryName) <= -1 then
                  Raise Exception.CreateFmt('�������� ���������� "%s" �� �������',[RasConn[i].szEntryName]);

               with FEntries[FEntries.IndexOfName(RasConn[i].szEntryName)] do
               begin
                  FConnected := true; //������ ������
                  FHandle := RasConn[i].hrasconn; // ������ �����

                  iBuffSize := sizeof(RASPppIp);
                  RASPppIp.dwSize := iBuffSize;
                  if 0 = RasGetProjectionInfo(FHandle, RASP_PppIp, Pointer(@RasPppIp), iBuffSize) then
                  begin // � �������� ��� ���������� ip ������ ������� � �������
                     FClientIP := RASPppIp.szIpAddress;
                     FServerIP := RASPppIp.szServerIpAddress;
                  end;
               end;
            end;
         end
         else
            Raise Exception.Create('������ ��� ����������� �������� ����������');
      end
      else
         Raise Exception.Create('������ ��� ����������� �������� ����������');
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
   // ������ ����� ������� RasEnumEntries ��������� ���������� ����������
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
         begin // ������ ����� ��� ����� ���� ����������
            for i := 0 to Pred(iEntries) do
            begin //��������� ����� ������ ���������� ������������
               Entries.AddItem(EntryNames[i].szEntryName);
               Entries.Items[i].GetProperties; //������ ���������� (����������/���������)
            end;
         end
         else
            raise Exception.Create('���������� ���������������� ���������� ����� ���������� �������');
      end
      else
         raise Exception.Create('���������� ���������������� ���������� ����� ���������� �������');
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
      RASCS_OpenPort:            Result := '��������� �����. ������� �������� �����';
      RASCS_PortOpened:          Result := '��������� �����. ���� ������';
      RASCS_ConnectDevice:       Result := '��������� �����. ������� ��������� �����';
      RASCS_DeviceConnected:     Result := '��������� �����. ����� �����������';
      RASCS_AllDevicesConnected: Result := '��������� �����. ��������� ����� ������������';
      RASCS_Authenticate:        Result := '��������������. ������ ��������� ��������������';
      RASCS_AuthNotify:          Result := '��������������. ��������� ��� ��������������';
      RASCS_AuthRetry:           Result := '��������������. ������� ��������� ��������������';
      RASCS_AuthCallback:        Result := '��������������. ������ �������� ������ ��� ��������� ������';
      RASCS_AuthChangePassword:  Result := '��������������. ������ ����� ������';
      RASCS_AuthProject:         Result := '��������������. ��������� �������� ��������������';
      RASCS_AuthLinkSpeed:       Result := '��������� �����. ������ �������� ����������';
      RASCS_AuthAck:             Result := '��������������. ������ �������������� �����������';
      RASCS_ReAuthenticate:      Result := '��������������. ��������� ��������������';
      RASCS_Authenticated:       Result := '��������������. �������������� ������������';
      RASCS_PrepareForCallback:  Result := '�������� �����. ������� ������ ����� ��� ��������� ��������� ������';
      RASCS_WaitForModemReset:   Result := '�������� �����. �������� ������ ������';
      RASCS_WaitForCallback:     Result := '�������� �����. �������� ��������� ������ �� �������';
      RASCS_Projected:           Result := '��������������. ��������� �������� �������������� ���������';
      RASCS_StartAuthentication: Result := '��������������. ������ ��������� ��������������';
      RASCS_CallbackComplete:    Result := '�������� �����. �������� ����� ��������';
      RASCS_LogonNetwork:        Result := '��������� �����. ����������� � ����';
      
      RASCS_Interactive:         Result := 'Interactive';
      RASCS_RetryAuthentication: Result := 'Retry Authentication';
      RASCS_CallbackSetByCaller: Result := 'Callback set by caller';
      RASCS_PasswordExpired:     Result := 'Password Expired';
      
      RASCS_Connected:           Result := '��������� ���������� �����������';
      RASCS_Disconnected:        Result := '��������� ���������� ���������';
    else
      Result := '����������� ������';
  end;
end;

function TRASClient.GetErrorString(Error: Integer): string;
var
   sErr: array [0..255] of char;
begin
   case Error of
      0: Result := 'OK';
      RASBASE+1: Result := '��������� �������� ���������� �����';
      RASBASE+2: Result := '�������� ���� ��� ������';
      RASBASE+3: Result := '����� ������� ������� ���';
      RASBASE+4: Result := '�������� �������� ����������';
      RASBASE+5: Result := '������ ��� ����� �� �����������';
      RASBASE+6: Result := '��������� ���� �� �����������';
      RASBASE+7: Result := '���������� �������� �������';
      RASBASE+8: Result := '��������� ���������� ����������� � �������';
      RASBASE+9: Result := '��� ���������� ���������� ����������� � �������';
      RASBASE+10: Result := '������ �������� �����';
      RASBASE+11: Result := '��������� ������� �� ��������';
      RASBASE+12: Result := '��������� ������� �� ��� ���������';
      RASBASE+13: Result := '������ �������� ��� ������ ������';
      RASBASE+14: Result := '�� �������� ������ ���������� �������';
      RASBASE+15: Result := '��������� ���� �� ������ � �������';
      RASBASE+16: Result := '��������� ������������� ����������� ������';
      RASBASE+17: Result := '���������� ��� ��������� �����';
      RASBASE+18: Result := '��������� ���� �� ������';
      RASBASE+19: Result := '����� � ��������� ����������� �� ����������� � ���� ������';
      RASBASE+20: Result := '�������� ����� �� ����������';
      RASBASE+21: Result := '�� ������� ������� ���� ���������� �����';
      RASBASE+22: Result := '�� ������� ��������� ���� ���������� �����';
      RASBASE+23: Result := '�� ������� ���������� ������ � ���������� ����� ��� ������� ����������';
      RASBASE+24: Result := '�� ������� �������� ���� ���������� �����';
      RASBASE+25: Result := '���������� �������� ���������� � ����� ���������� �����';
      RASBASE+26: Result := '�� ������� ��������� ������';
      RASBASE+27: Result := '�� ������� ����� ����';
      RASBASE+28: Result := '���������� ���� �������� ��������� ����������� �� ����, ��� ���� ���������';
      RASBASE+29: Result := '���������� ���� ������� ��������� �����������';
      RASBASE+30: Result := '���������� ��������� ����� ��-�� ���������� ������';
      RASBASE+31: Result := '������������ �������� �����';
      RASBASE+32: Result := '��������� �������� ������ ���������';
      RASBASE+33: Result := '���������� ��� ������������ ��� �� ��������� �� ������ � ������ ���������� �������';
      RASBASE+34: Result := '��������� �� ��� ��������������� � ����';
      RASBASE+35: Result := '����������� ������';
      RASBASE+36: Result := '���������� ������������ � ����� �� ���� ����';
      RASBASE+37: Result := '���������� ������������ ������';
      RASBASE+38: Result := '��������� ������ �� ������� �� ����� ������';
      RASBASE+43: Result := '������ �������� �������� �������';
      RASBASE+45: Result := '���������� ������ ��������������';
      RASBASE+46: Result := '� ��� ����� ��������� ������������ ����������';
      RASBASE+47: Result := '���������� ���������';
      RASBASE+48: Result := '���� �������� ������ �����';
      RASBASE+49: Result := '� ������������ ��� ���� �� ��������� ��������� ����������';
      RASBASE+50: Result := '��������� ������ �� ��������';
      RASBASE+51: Result := '������ ����������';
      RASBASE+52: Result := '����������� ������ �� ����������';
      RASBASE+65: Result := '���������� �� ��������� �� ������ � ������ ���������� �������';
      RASBASE+66: Result := '���������� �� ������������';
      RASBASE+68: Result := '���������� ���������';
      RASBASE+76: Result := '���������� ����� ������';
      RASBASE+77: Result := '��������� ����� �������';
      RASBASE+78: Result := '��������� ��������� �� ������� �� ������� ����������';
      RASBASE+79: Result := '��� ������� � ���������� �����';
      RASBASE+80: Result := '��� ���������� ������� � ���������� �����';
      RASBASE+81: Result := '���������� �������� �� ������';
      RASBASE+91: Result := '������ ��������. ��� ������������ �/��� ������ �� ������� � ������';
      RASBASE+92: Result := '���������� ������ ����������';
      RASBASE+108: Result := '���� �������� ������� ������ �����';
      RASBASE+109: Result := '������ ��� ������� ����� ������';
      RASBASE+115: Result := '������� ����� ������ - ������ �������� ���������� �����';
      RASBASE+118: Result := '�������� ���� �������� ������ �� �������';
      RASBASE+119: Result := 'C��������� �������� ��������� �����������';
      RASBASE+120: Result := '���������� ���������� ���������� � ��������� �����������. �������� ������� ��������� ����';
      RASBASE+121: Result := '��������� ��������� �� ��������';
      RASBASE+122: Result := '�� ���������� ���������� �������� �������� ������';
      RASBASE+128: Result := '������� �� ������� ����� ������� ��������� IP';
      RASBASE+129: Result := 'SLIP cannot be used unless the IP protocol is installed';
      RASBASE+130: Result := '����������� ���������� � ���� �� ���������';
      RASBASE+131: Result := '�������� �� �������� �� ������ � ������ ���������� �������';
      RASBASE+138: Result := '��������� ������ �� ������� IP-�����';
      RASBASE+139: Result := '�������� ������������ �� ��������� ������������ ������, ����������� Windows. ��������� ������ ���� ������';
      else
      begin
      	RasGetErrorString(Error, @sErr[0], 256);
      	Result := sErr;	
      end;
   end;
end;

end.

