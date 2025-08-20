<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<html>
<head><title>Message Board</title></head>
<body>
<h1>Welcome! You've visited this page ${visits} times.</h1>
<form method="POST">
    <input type="text" name="message" required>
    <input type="submit" value="Send Message">
</form>
<h2>Messages:</h2>
<ul>
    <c:forEach var="msg" items="${messages}">
        <li><strong>${msg.id}:</strong> ${msg.text}</li>
    </c:forEach>
</ul>
</body>
</html>