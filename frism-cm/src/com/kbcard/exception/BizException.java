package com.kbcard.excption;

public class BizException extends Exception
{
	private String code;
	private String user;
	
	public BizException(String code, String msg, String user)
	{
		super(msg);
		this.code = code;
	    this.user = user;
	}
	
	public String toString()
	{
		return "오류코드: "+code+", 오류내용: "+getLocalizedMessage()+", 오류상세: "+user;
	}
	
	public String getCode()
	{
		return code;
	}
	
	public String getDetailMessage()
	{
		return user;
	}
}