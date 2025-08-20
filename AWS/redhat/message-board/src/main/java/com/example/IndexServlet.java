package com.example;

import javax.servlet.RequestDispatcher;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

import java.io.IOException;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

@WebServlet("/")
public class IndexServlet extends HttpServlet {
    private static final String DB_URL = System.getenv("DB_URL");
    private static final String DB_USER = System.getenv("DB_USER");
    private static final String DB_PASS = System.getenv("DB_PASS");

    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession session = request.getSession();
        Integer visits = (Integer) session.getAttribute("visits");
        if (visits == null) {
            visits = 1;
        } else {
            visits++;
        }
        session.setAttribute("visits", visits);

        List<Message> messages = new ArrayList<>();
        try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery("SELECT id, message FROM messages ORDER BY id")) {
            while (rs.next()) {
                messages.add(new Message(rs.getInt("id"), rs.getString("message")));
            }
        } catch (SQLException e) {
            throw new ServletException("DB error", e);
        }

        request.setAttribute("messages", messages);
        request.setAttribute("visits", visits);
        RequestDispatcher dispatcher = request.getRequestDispatcher("/index.jsp");
        dispatcher.forward(request, response);
    }

    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String message = request.getParameter("message").trim();
        if (!message.isEmpty()) {
            try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
                    PreparedStatement pstmt = conn.prepareStatement("INSERT INTO messages (message) VALUES (?)")) {
                pstmt.setString(1, message);
                pstmt.executeUpdate();
            } catch (SQLException e) {
                e.printStackTrace(); // logs the exact DB error to Tomcat
                throw new ServletException("DB error", e);
            }

        }
        response.sendRedirect("/");
    }

    public static class Message {
        int id;
        String text;

        public Message(int id, String text) {
            this.id = id;
            this.text = text;
        }

        public int getId() {
            return id;
        }

        public String getText() {
            return text;
        }
    }
}