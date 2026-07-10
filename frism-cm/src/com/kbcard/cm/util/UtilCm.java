package com.kbcard.cm.util;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;

import com.kbcard.excption.BizException;
import com.kbcard.frism.manager.KbCardCmManager;
import com.kbcard.frism.object.CmPackage;
import com.kbcard.frism.object.CmResource;

import frism.common.LicenseFile;

public class UtilCm
{
	private static UtilCm instance;
	
	private boolean        isInit;     // 초기화여부
	private LicenseFile    license;    // 라이센스정보
	
	// Singleton 인스턴스
    private static UtilCm getInstance()
    {
        if (instance == null)
        {
            synchronized (UtilCm.class)
            {
                if (instance == null)
                    instance = new UtilCm();
            }
        }
        return instance;
    }
    
    private UtilCm()
    {
        if (!isInit)
            init();
    }
    
    // 초기화
    public void init()
    {
        license = new LicenseFile(System.getProperty("frism.license.path"));
    }
    
    // 라이센스정보 가져오기
    public LicenseFile getLicense()
    {
        return license;
    }
    
    /**
     * CM 솔루션 접속
     * @param userId 직원번호
     * @return CM 데이터정보
     * @throws Exception
     * @author 2019.7.8 / 주재현
     */
    public static UtilCmData connect(String userId) throws BizException
    {
        UtilCmData      utilCmData  = null;
        KbCardCmManager kbcm    	= null;

        kbcm = new KbCardCmManager(UtilCm.getInstance().getLicense(), null);
        
        try
        {
            kbcm.connect();
        }
        catch (Exception e)
        {
            CmErrConst error = CmErrConst.UCXO6811;
            throw new BizException(error.getCode(), error.getDesc(), " 형상관리 연결 중 오류발생!, msg="+kbcm.getLastErrorMassege());
        }
        
        utilCmData = new UtilCmData();
        utilCmData.setCmManager(kbcm);
        
        return utilCmData;
    }
    
    /**
     * CM패키지 반환
     * @param UtilCmData CM 데이터정보
     * @param cmId CM ID (null일 경우 생성)
     * @return CM 데이터 정보
     * @throws Exception
     * @author 2019.7.8 / 주재현
     */
    public static UtilCmData getCm(UtilCmData utilCmData, String cmId, String userId) throws BizException
    {
        com.kbcard.frism.object.CmPackage cm = null;
        int ret = -1;

        // CM생성
        if (cmId == null)
        {
            cmId = utilCmData.getCmManager().createCm("CXT", "CXT_API자동생성_"+getCurrentDateTime(), "API를 통한 자동생성 CM", getCurrentDateTime(), userId);
            if (cmId == null)
            {
                CmErrConst error = CmErrConst.UCXO6812;
                throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "", ret));
            }
        }
        
        cm = utilCmData.getCmManager().getCmByCmId(cmId);
        utilCmData.setCm(cm);
        
        return utilCmData;
    }
    
    /**
     * 레파지토리 ID 반환
     * @param UtilCmData CM 데이터정보
     * @param repositoryName 레파지토리명
     * @return 레파지토리 ID
     * @throws Exception
     * @author 2019.7.8 / 주재현
     */
    public static int getRepositoryId(UtilCmData utilCmData, String repositoryName) throws BizException
    {
        int repId = -1;
        try
        {
            repId = utilCmData.getCmManager().getRepositoryId(repositoryName);
        }
        catch (Exception e)
        {
            CmErrConst error = CmErrConst.UCXO6813;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, ""));
        }
        
        return repId;
    }
    
    public static void addResource(UtilCmData utilCmData, int repositoryId, String filePath, String fileName, String userId) throws BizException
    {
    	addResource(utilCmData, repositoryId, filePath, fileName, userId, "spider");
    }
    
    /**
     * 자원 입력
     * @param UtilCmData CM 데이터 정보
     * @param repositoryId 레파지토리 id
     * @param filePath 파일경로
     * @param fileName 파일명
     * @throws Exception
     * @author 2019.7.8 / 주재현
     */
    public static void addResource(UtilCmData utilCmData, int repositoryId, String filePath, String fileName, String userId, String desc) throws BizException
    {
        // check in (자체적으로 체크인 하여 제외)
        //checkIn(UtilCmData, repositoryId, filePath, fileName);
            
        // save resource
        int ret = -1;
        try
        {
            ret = utilCmData.getCmManager().addResourceToCmSaveInternet(repositoryId, utilCmData.getCm().getCmId(), filePath, fileName, desc, "", userId);
            
            if (ret == -505)
            {
                CmErrConst error = CmErrConst.UCXO6814;
                throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "", ret));
            }
            else if (ret < 0) 
            {
                CmErrConst error = CmErrConst.UCXO6815;
                throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "", ret));
            }
        }
        catch (Exception e)
        {
            CmErrConst error = CmErrConst.UCXO6816;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, ""));
        }
    }
    
    public static void deployStage(UtilCmData utilCmData) throws BizException
    {
        deploy(utilCmData, true, null);
    }
 
    public static void deployReal(UtilCmData utilCmData) throws BizException
    {
        deploy(utilCmData, false, null);
    }
    
    public static void deployReal(UtilCmData utilCmData, String deployTime) throws BizException
    {
        deploy(utilCmData, false, deployTime);
    }
    
    /**
     * CM 디플로이
     * @param UtilCmData CM 데이터 정보
     * @param isStage 스테이징/운영 구분 (true: 스테이징, false: 운영)
     * @throws Exception
     * @author 2019.7.8 / 주재현 
     */
    private static void deploy(UtilCmData utilCmData, boolean isStage, String deployTime) throws BizException
    {
        String cmId = utilCmData.getCm().getCmId();
        
        if (deployTime == null)
        	deployTime = new SimpleDateFormat("yyyyMMddHHmm").format(new Date());
        
        int ret = -1;
        try
        {
            ret = utilCmData.getCmManager().deployExec(cmId, deployTime, isStage ? 3: 4);
            if (!isSuccess(ret))
            {
                CmErrConst error = CmErrConst.UCXO6817;
                throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "", ret));
            }
        }
        catch (Exception e)
        {
            CmErrConst error = CmErrConst.UCXO6817;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "기타오류발생, "));
        }
    }
    
    /**
     * CM 솔루션 해제
     * @param UtilCmData
     * @throws Exception
     * @author 2019.7.9 / 주재현
     */
    public static void disconnect(UtilCmData utilCmData) throws BizException
    {
        try
        {
        	utilCmData.getCmManager().disconnect();
        }
        catch (Exception e)
        {
            CmErrConst error = CmErrConst.UCXO6818;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, ""));
        }
    }
    
    /**
     * CM 스테이징 상태가 완료 되었는지 여부를 반환한다.<br>
     * 이 함수는 형상관리 연결 및 CM 데이터를 가져오는 작업이 안된 상태에서만 사용하길 권장함
     * @param userId 사용자 ID
     * @param cmId
     * @return
     * @throws BizException
     */
    public static boolean isStateCmStatusEnd(String userId, String cmId) throws BizException
    {
        UtilCmData cmData = connect(userId);
        cmData = getCm(cmData, cmId, userId);
        return isStateCmStatusEnd(cmData);
    }
    
    /**
     * CM 스테이징 상태가 완료 되었는지 여부를 반환한다.
     * @param UtilCmData CM 데이터 정보
     * @return
     * @throws BizException
     */
    public static boolean isStateCmStatusEnd(UtilCmData UtilCmData)
    {
        String rst = UtilCmData.getCm().getCmTestStatus();
        if ("P".equals(rst))
            return true;
               
        return false;
    }
    
    /**
     * CM 운영 상태가 완료 되었는지 여부를 반환한다.<br>
     * 이 함수는 형상관리 연결 및 CM 데이터를 가져오는 작업이 안된 상태에서만 사용하길 권장함
     * @param userId 사용자 ID
     * @param cmId
     * @return
     * @throws BizException
     */
    public static boolean isRealCmStatusEnd(String userId, String cmId) throws BizException
    {
        UtilCmData cmData = connect(userId);
        cmData = getCm(cmData, cmId, userId);
        return isRealCmStatusEnd(cmData);
    }
    
    /**
     * CM 운영 상태가 완료 되었는지 여부를 반환한다.
     * @param UtilCmData CM 데이터 정보
     * @return
     * @throws BizException
     */
    public static boolean isRealCmStatusEnd(UtilCmData UtilCmData)
    {
        String rst = UtilCmData.getCm().getCmStatus();
        if ("P".equals(rst))
            return true;
               
        return false;
    }
    
    public static void checkIn(UtilCmData UtilCmData, int repositoryId, String filePath, String fileName, boolean isCrc, String userId) throws BizException
    {
        checkIn(UtilCmData, repositoryId, filePath, fileName, isCrc, false, userId);
    }
    
    public static void checkIn(UtilCmData utilCmData, int repositoryId, String filePath, String fileName, boolean isCrc, boolean isNewFile, String userId) throws BizException
    {
    	  checkIn(utilCmData, repositoryId, filePath, fileName, isCrc, isNewFile, userId, "spider"); 
    }
    
    /**
     * 파일 반입
     * @param UtilCmData CM 데이터 정보
     * @param repositoryId 레파지토리 ID
     * @param filePath 파일경로
     * @param fileName 파일명
     * @param isCrc 
     * @param isNewFile 신규여부
     * @throws Exception
     * @author 2019.7.15 / 주재현
     */
    public static void checkIn(UtilCmData utilCmData, int repositoryId, String filePath, String fileName, boolean isCrc, boolean isNewFile, String userId, String desc) throws BizException
    {
        if (isNewFile)
        {
            try
            {
            	utilCmData.getCmManager().addResource(repositoryId, filePath, filePath+fileName, desc, userId);
            }
            catch (Exception e)
            {
                CmErrConst error = CmErrConst.UCXO6826;
                throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, ""));
            }
        }
        else
        {
            int ret = utilCmData.getCmManager().checkIn(repositoryId, filePath, filePath+fileName, desc, isCrc, userId);
            if (!isSuccess(ret))
            {
                CmErrConst error = CmErrConst.UCXO6819;
                throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "", ret));
            }
        }
    }
    
    /**
     * 파일 반출
     * @param UtilCmData CM 데이터 정보
     * @param repositoryId 레파지토리 ID
     * @param filePath 파일경로
     * @param fileName 파일명
     * @param isOverride 자원 덮어쓰기 여부
     * @throws Exception
     * @author 2019.7.10 / 주재현
     */
    public static void checkOut(UtilCmData utilCmData, int repositoryId, String filePath, String fileName, boolean isOverride, String userId) throws BizException
    {
        int ret = -1;
        try
        {
            ret = utilCmData.getCmManager().checkOut(repositoryId, filePath, filePath+fileName, isOverride, userId);
            if (!isSuccess(ret))
            {
                CmErrConst error = CmErrConst.UCXO6820;
                throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "", ret));
            }
        }
        catch (Exception e)
        {
            CmErrConst error = CmErrConst.UCXO6820;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "기타오류발생, "));
        }
    }
    
    /**
     * 파일 ID 가져오기 (기존 사용하는 함수명을 변경할 수 없어 ResId 로 변경하지 않았음)
     * @param UtilCmData CM 데이터 정보
     * @param repositoryId 레파지토리 ID
     * @param filePath 파일경로
     * @param fileName 파일명
     * @return 파일 ID
     * @throws Exception
     * @author 2019.7.10 / 주재현
     */
    public static int getFileId(UtilCmData utilCmData, int repositoryId, String filePath, String fileName) throws BizException
    {
        // get file id
        int fileId = utilCmData.getCmManager().getResId(repositoryId, filePath, fileName);
        if (fileId <= 0) 
        {
            CmErrConst error = CmErrConst.UCXO6821;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, ""));
        }
        
        return fileId;
    }
    
    /**
     * 실제 파일ID를 가져오는 함수 <code>getFileId</code> 함수는 getResId 처리임
     * @param utilCmData
     * @param repositoryId
     * @param filePath
     * @param fileName
     * @return
     * @throws BizException
     */
    public static int getFileId2(UtilCmData utilCmData, int repositoryId, String filePath, String fileName) throws BizException
    {
        // get file id
        int fileId = utilCmData.getCmManager().getFileId(repositoryId, filePath, fileName);
        if (fileId <= 0) 
        {
            CmErrConst error = CmErrConst.UCXO6821;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, ""));
        }
        
        return fileId;
    }
    
    /**
     * 파일 반출 취소
     * @param UtilCmData CM 데이터 정보
     * @param repositoryId 레파지토리 ID
     * @param filePath 파일경로
     * @param fileName 파일명
     * @throws Exception
     * @author 2019.7.10 / 주재현
     */
    public static void checkOutCancel(UtilCmData utilCmData, int repositoryId, String filePath, String fileName, String userId) throws BizException
    {
        int ret = utilCmData.getCmManager().checkOutCancel(repositoryId, filePath, filePath+fileName, userId);
        if (!isSuccess(ret))
        {
            CmErrConst error = CmErrConst.UCXO6822;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "", ret));
        }
    }
    
    /**
     * CM 파일 삭제
     * @param UtilCmData CM 데이터 정보
     * @param arrRepositoryId 레파지토리 ID 리스트
     * @param arrFilePath 파일 경로 리스트
     * @param arrFileName 파일 명 리스트
     * @throws Exception
     * @author 2019.7.10 / 주재현
     */
    public static void cmSaveCancel(UtilCmData utilCmData, String arrRepositoryId[], String arrFilePath[], String arrFileName[]) throws BizException
    {
    	int ret = utilCmData.getCmManager().cmSaveCancel(utilCmData.getCm().getCmId(), arrRepositoryId, arrFilePath, arrFileName);
        if (!isSuccess(ret))
        {
            CmErrConst error = CmErrConst.UCXO6823;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "", ret));
        }
    }

    /**
     * CM 리소스 가져오기
     * @param UtilCmData UtilCmData CM 데이터 정보
     * @param repositoryId 레파지토리 ID
     * @param filePath 파일 경로
     * @param fileName 파일 명
     * @return CM 리소스
     * @throws Exception
     * @author 2019.7.10 / 주재현
     */
    public static ArrayList<HashMap<String, String>> getVersionListByResId(UtilCmData utilCmData, int repositoryId, int fileId) throws BizException
    {
        try
        {
        	utilCmData.clearCmResourceVersion();
        	CmResource[] cmResource = utilCmData.getCmManager().getVersionListByResId(repositoryId, fileId);
            for (CmResource resource: cmResource)
            {
            	utilCmData.setResourceVersion(resource);
            }
            
            return utilCmData.getResourceVersion();
        }
        catch (Exception e)
        {
            CmErrConst error = CmErrConst.UCXO6824;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, ""));
        }
        
    }
    
    /**
     * 파일 다운로드
     * @param UtilCmData CM 데이터 정보
     * @param fileId 파일 ID
     * @param downloadPath 다운로드 경로
     * @throws Exception
     * @author 2019.7.10 / 주재현
     */
    public static void getDownloadResource(UtilCmData utilCmData, int fileId, String version, String downloadPath) throws BizException
    {
        int ret = utilCmData.getCmManager().getDownloadResource(fileId, version, downloadPath);
        if (!isSuccess(ret))
        {
            CmErrConst error = CmErrConst.UCXO6825;
            throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, "", ret));
        }
    }
    
    /**
     * CM 패키지 리스트
     * @param UtilCmData CM 데이터 정보
     * @param cmPackgekName 
     * @return CM 패키지 리스트
     * @throws Exception
     */
    public static ArrayList<HashMap<String, String>> getCMList(UtilCmData utilCmData, String cmPackgekName, String userId)
    {
    	  CmPackage[] cmPackageList = utilCmData.getCmManager().getCMList(cmPackgekName, userId);
        for (CmPackage pkg: cmPackageList)
        {
        	utilCmData.setCmPackage(pkg);
        }
        
        return utilCmData.getCmPackage();
    }
    
    /**
     * CM패키지의 상태를 반환한다.
     * @param UtilCmData
     * @return
     * @throws BizException
     */
    public static String getCmStatus(UtilCmData utilCmData) throws BizException
    {
    	String status = null;
    	try
    	{
    		status = utilCmData.getCm().getStatus();
    	}
    	catch (Exception e)
    	{
    		  CmErrConst error = CmErrConst.UCXO6827;
    		  throw new BizException(error.getCode(), error.getDesc(), getErrorMsg(utilCmData, ""));
    	}
    	return status;
    }
    
    /**
     * 파일 반출 사용자
     * @param UtilCmData CM 데이터 정보
     * @param fileId 파일 ID
     * @return 파일 반출 사용자
     * @throws Exception
     * @author 2019.7.10 / 주재현
     */
    public static String getCheckoutUserId(UtilCmData utilCmData, int fileId)
    {
        return utilCmData.getCmManager().getCheckoutUserId(fileId);
    }
    
    // 프리즘 결과 코드의 성공여부를 반환한다.
    private static boolean isSuccess(int ret)
    {
        if (ret < 0)
            return false;
        
        return true;
    }
    
    // 프리즘 결과 코드에 대한 오류코드를 반환한다.
    public static String getErrorMsg(UtilCmData utilCmData, String msg)
    {
        return msg+"msg="+utilCmData.getCmManager().getLastErrorMassege();
    }
    
    // 프리즘 결과 코드에 대한 오류코드를 반환한다.
    public static String getErrorMsg(UtilCmData utilCmData, String msg, int ret)
    {
        return msg+"code="+utilCmData.getCmManager().getErrorMassege(ret)+", msg="+utilCmData.getCmManager().getLastErrorMassege();
    }
    
    private static String getCurrentDateTime()
	{
    	SimpleDateFormat formatter = new SimpleDateFormat("yyyyMMddHHmmss");
		return formatter.format(new Date());
	}
}

enum CmErrConst
{
    UCXO6810("UCXO6810", "형상관리 미등록 사용자"),
    UCXO6811("UCXO6811", "형상관리 연결실패"),
    UCXO6812("UCXO6812", "CM 패키지 생성실패"),
    UCXO6813("UCXO6813", "레파지토리 ID 가져오기 실패"),
    UCXO6814("UCXO6814", "CM 자원이 다른곳에 반입되어 있음"),
    UCXO6815("UCXO6815", "CM 저장 실패"),
    UCXO6816("UCXO6816", "CM 자원 저장중 기타오류발생"),
    UCXO6817("UCXO6817", "CM 디플로이 실패"),
    UCXO6818("UCXO6818", "CM 종료처리 중 오류발생"),
    UCXO6819("UCXO6819", "CM 자원 반입중 실패"),
    UCXO6820("UCXO6820", "CM 자원 반출중 실패"),
    UCXO6821("UCXO6821", "형상 소스없음"),
    UCXO6822("UCXO6822", "CM 자원 반출 취소중 실패"),
    UCXO6823("UCXO6823", "CM 자원 파일 삭제중 실패"),
    UCXO6824("UCXO6824", "CM 버전별 리소스 가져오기 실패"),
    UCXO6825("UCXO6825", "파일 다운로드 실패"),
    UCXO6826("UCXO6826", "신규파일 생성실패"),
    UCXO6827("UCXO6827", "해당 CM패키지가 없거나 개발확정 상태이오니 통합품질관리시스템(IQMS) 해당 CM패키지의 상태를 확인해 주십시오.");
    
    private String code;    // 오류코드
    private String desc;    // 오류설명
    
    CmErrConst(String code, String desc)
    {
        this.code = code;
        this.desc = desc;
    }
    
    public String getCode()
    {
        return this.code;
    }
    
    public String getDesc()
    {
        return this.desc;
    }
}